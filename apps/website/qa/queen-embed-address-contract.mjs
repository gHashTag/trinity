// Does the Queen's address name the card each embedded Explorer shows?
//
// Seven Queen tabs frame an Explorer: SPECS, SKILLS, CRONS, AGENTS, FUNCTIONS, TOOLS
// and PROJECT (the system docs). Measured on t27.ai before lib/queenEmbed: a pick
// inside a frame changed only the frame's own hash, so a reload, a shared link or the
// language toggle opened the default card; #/queen?tab=skills&skill=... opened the
// default skill; and the ladder link Skills inside the agents frame put the Skill
// Explorer under a rail and an address that still said AGENTS.
//
// This opens the built page in real Chrome and checks, against the live DOM of the
// frame and the Queen: a deep link opens the named card in every tab; a pick writes
// the address without a history entry and survives a reload; an outside hash change
// and Back move the frame; the language toggle keeps the card and writes ?lang=; a
// link to another Explorer switches the Queen's tab; an address without a card takes
// the frame's; a refused id falls back to the default; an unknown chapter is corrected
// to the chapter on show, while an unknown skill keeps the Explorer's own not-found
// card. Every step starts from a state that differs from what it asserts, so no check
// passes because the frame already showed the thing.
//
//   npm run check:queen-embed                         build, then check
//   npm run check:queen-embed -- --no-build           reuse dist/
//   node qa/queen-embed-address-contract.mjs --origin=http://127.0.0.1:8000
//                                                     check a build served elsewhere
//
// Exit 0: every check passed. 1: a check failed. 2: the check could not run (no
// Chrome, no page) -- never read that as a pass. The harness is the other Queen
// contracts': dist over node:http, the installed Chrome with --headless=new, CDP over
// Node's WebSocket, and a deadline on every evaluate so a busy renderer cannot hang it.
import { execSync, spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { readFileSync, existsSync, mkdtempSync, rmSync } from 'node:fs';
import { join, extname, normalize } from 'node:path';
import { tmpdir } from 'node:os';

const ROOT = new URL('..', import.meta.url).pathname;
const DIST = join(ROOT, 'dist');
const ORIGIN_ARG = process.argv.find((a) => a.startsWith('--origin='))?.slice('--origin='.length).replace(/\/$/, '');
const EVAL_TIMEOUT_MS = Number(process.env.EMBED_EVAL_TIMEOUT_MS || 60000);
const DEADLINE_MS = Number(process.env.EMBED_DEADLINE_MS || 45 * 60000);

const CHROME = [
  process.env.CHROME_PATH,
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/Applications/Chromium.app/Contents/MacOS/Chromium',
  '/usr/bin/google-chrome', '/usr/bin/chromium-browser', '/usr/bin/chromium',
].filter(Boolean).find((p) => existsSync(p));
if (!CHROME) { console.log('  no Chrome found -- the embed address check could not run. Set CHROME_PATH.'); process.exit(2); }

const checks = [];
const record = (name, ok, detail) => { checks.push({ name, ok: !!ok, detail }); console.log(`  ${ok ? 'PASS' : 'FAIL'}  ${name}`); };
const report = (code, extra = {}) => {
  const failed = checks.filter((c) => !c.ok);
  for (const c of failed) console.log(`\n  FAIL ${c.name}\n  ${JSON.stringify(c.detail).slice(0, 1500)}`);
  console.log(`\n  Queen embed address contract: ${extra.couldNotRun ? `COULD NOT RUN (${extra.couldNotRun})` : failed.length ? `FAIL (${failed.length} of ${checks.length})` : `PASS (${checks.length} checks)`}`);
  process.exit(code);
};
const deadline = setTimeout(() => report(2, { couldNotRun: `deadline ${DEADLINE_MS / 60000} min` }), DEADLINE_MS);
const wait = (ms) => new Promise((r) => setTimeout(r, ms));

// ── The page: a served origin, or dist served the way Pages serves it ──
let origin = ORIGIN_ARG;
let server = null;
if (!origin) {
  if (!process.argv.includes('--no-build')) {
    console.log('  building…');
    execSync('npx vite build', { cwd: ROOT, stdio: ['ignore', 'ignore', 'inherit'] });
  }
  if (!existsSync(join(DIST, 'index.html'))) { console.error('  dist/index.html missing -- nothing to open.'); process.exit(2); }
  const MIME = {
    '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.css': 'text/css', '.json': 'application/json',
    '.svg': 'image/svg+xml', '.png': 'image/png', '.jpg': 'image/jpeg', '.webp': 'image/webp', '.ico': 'image/x-icon',
    '.wasm': 'application/wasm', '.woff2': 'font/woff2', '.t27': 'text/plain', '.md': 'text/markdown',
  };
  server = createServer((req, res) => {
    const path = normalize(decodeURIComponent(req.url.split('?')[0])).replace(/^(\.\.[/\\])+/, '');
    let file = join(DIST, path);
    if (!file.startsWith(DIST) || !existsSync(file) || path === '/') file = join(DIST, 'index.html');
    try { res.writeHead(200, { 'Content-Type': MIME[extname(file)] || 'application/octet-stream' }); res.end(readFileSync(file)); } catch { res.writeHead(500); res.end(); }
  });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  origin = `http://127.0.0.1:${server.address().port}`;
}

// ── Chrome over CDP ──
const profile = mkdtempSync(join(tmpdir(), 'queen-embed-'));
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=0', `--user-data-dir=${profile}`, '--no-first-run', '--no-default-browser-check',
  '--disable-extensions', '--window-size=1440,900', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', 'about:blank'], { stdio: ['ignore', 'ignore', 'pipe'] });
process.on('exit', () => { try { chrome.kill('SIGKILL'); } catch { /* gone */ } try { rmSync(profile, { recursive: true, force: true }); } catch { /* gone */ } server?.close(); });

let p;
try {
  const wsUrl = await new Promise((resolve, reject) => {
    const t = setTimeout(() => reject(new Error('Chrome never announced a debugging port')), 30000);
    let buf = '';
    chrome.stderr.on('data', (d) => { buf += d; const m = buf.match(/DevTools listening on (ws:\/\/\S+)/); if (m) { clearTimeout(t); resolve(m[1]); } });
  });
  const ws = new WebSocket(wsUrl);
  await new Promise((res, rej) => { ws.onopen = res; ws.onerror = () => rej(new Error('CDP socket refused')); });
  let id = 0; const pending = new Map(); const listeners = [];
  ws.onmessage = (ev) => { const m = JSON.parse(ev.data); if (m.id && pending.has(m.id)) { const q = pending.get(m.id); pending.delete(m.id); if (m.error) q.reject(new Error(m.error.message)); else q.resolve(m.result); } else if (m.method) listeners.forEach((f) => f(m)); };
  const send = (method, params = {}, sessionId) => new Promise((resolve, reject) => { const i = ++id; pending.set(i, { resolve, reject }); ws.send(JSON.stringify({ id: i, method, params, ...(sessionId ? { sessionId } : {}) })); });
  const { targetId } = await send('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await send('Target.attachToTarget', { targetId, flatten: true });
  const call = (m, q) => send(m, q, sessionId);
  const errors = [];
  listeners.push((m) => { if (m.sessionId === sessionId && m.method === 'Runtime.exceptionThrown') { const d = m.params.exceptionDetails; errors.push((d.exception?.description ?? d.text).split('\n').slice(0, 3).join(' | ')); } });
  await call('Runtime.enable'); await call('Page.enable');
  const evaluate = async (expr) => {
    const r = await Promise.race([
      call('Runtime.evaluate', { expression: expr, awaitPromise: true, returnByValue: true }),
      new Promise((_, rej) => setTimeout(() => rej(new Error(`evaluate timed out after ${EVAL_TIMEOUT_MS} ms`)), EVAL_TIMEOUT_MS)),
    ]);
    if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description || r.exceptionDetails.text);
    return r.result.value;
  };
  const until = async (expr, ms) => { const start = Date.now(); while (Date.now() - start < ms) { try { const v = await evaluate(expr); if (v) return v; } catch { /* the page is between documents */ } await wait(300); } return null; };
  const onLoad = () => new Promise((r) => { const t = setTimeout(r, 45000); listeners.push((m) => { if (m.sessionId === sessionId && m.method === 'Page.loadEventFired') { clearTimeout(t); r(); } }); });
  const load = async (url) => { const loaded = onLoad(); await call('Page.navigate', { url }); await loaded; };
  const reload = async () => { const loaded = onLoad(); await call('Page.reload', {}); await loaded; };
  const clickAt = async (x, y) => {
    await call('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', clickCount: 1 });
    await call('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', clickCount: 1 });
  };
  p = { evaluate, until, load, reload, clickAt, errors };
} catch (e) {
  report(2, { couldNotRun: String(e?.message || e) });
}

const KEY = { skills: 'skill', crons: 'cron', agents: 'agent', functions: 'function', tools: 'tool', specs: 'spec', project: 'chapter' };
const TITLE = { skills: 'Skill Explorer', crons: 'Cron Explorer', agents: 'Agent Explorer', functions: 'Function Explorer', tools: 'Tool Explorer', specs: 'Spec Explorer', project: 'System documentation' };
const nonce = String(process.pid);

const TOP = `(() => ({ hash: location.hash, search: location.search, params: Object.fromEntries(new URLSearchParams(location.hash.split('?')[1] || '')),
  view: document.querySelector('main[data-view]')?.getAttribute('data-view') ?? null, active: document.querySelector('button.queen27-hud-cmd.is-active')?.dataset.view ?? null,
  jump: document.querySelector('.queen27-docs-jump.is-active')?.textContent ?? null, histLen: history.length, frames: document.querySelectorAll('iframe.queen27-specs-frame').length, lang: document.documentElement.lang }))()`;
// The frame as it is on screen: its route, the item marked current, the docs heading.
const FRAME = `(() => { const f = document.querySelector('iframe.queen27-specs-frame'); if (!f) return null; let w, d; try { w = f.contentWindow; d = w && w.document; if (!d || !d.body) return null; } catch { return null }
  const h = w.location.hash; const r = /^#\\/([a-z]+)(?:\\/([^?#]*))?/.exec(h) || [];
  return { title: f.getAttribute('title'), hash: h, route: r[1] ?? null, stem: r[2] ?? null, params: Object.fromEntries(new URLSearchParams(h.split('?')[1] || '')), lang: d.documentElement.lang,
    current: [...d.querySelectorAll('[aria-current="true"]')].map((e) => e.getAttribute('aria-label') || '').filter(Boolean),
    h1: d.querySelector('h1')?.textContent.trim().slice(0, 80) ?? null, notFound: /missing or ambiguous/.test(d.body.innerText || '') } })()`;

/**
 * Does the frame show `id` of `kind`? The frame's own address (each Explorer writes it
 * when it opens a card) and the item it marks current; where that item's label carries
 * the id the label must name it -- a skill's ends with it, a spec's reads
 * "module — path, N lines, health", an agent's starts with the letter -- and the docs
 * heading must carry the chapter's number. The cron, function and tool labels end with
 * a schedule, a trigger or a source instead, so there the address and a marked item
 * are the evidence.
 */
const SHOWS = `(f, kind, id, KEY, chapterOrder) => {
  if (!f) return false;
  if (kind === 'project') return f.route === 'docs' && (f.stem || 'project') === id && new RegExp('^(Chapter|Глава) ' + chapterOrder[id] + '(?!\\\\d)').test(f.h1 || '');
  if (f.route !== kind || f.params[KEY[kind]] !== id) return false;
  if (kind === 'agents') return f.current.some((l) => l.startsWith(id + ' ·'));
  if (kind === 'skills') return f.current.some((l) => l.endsWith(' — ' + id));
  if (kind === 'specs') return f.current.some((l) => l.includes(' — ' + id + ','));
  return f.current.length > 0;
}`;

const top = () => p.evaluate(TOP);
const frame = () => p.evaluate(FRAME);
let chapterOrder = {};
const showsExpr = (kind, id) => `(${SHOWS})(${FRAME}, ${JSON.stringify(kind)}, ${JSON.stringify(id)}, ${JSON.stringify(KEY)}, ${JSON.stringify(chapterOrder)})`;
const waitShows = async (kind, id, ms = 120000) => !!(await p.until(showsExpr(kind, id), ms));
const nowShows = async (kind, id) => { try { return !!(await p.evaluate(showsExpr(kind, id))); } catch { return false; } };
const shell = async (url) => { await p.load(url); return !!(await p.until(`document.querySelectorAll('button.queen27-hud-cmd[data-view]').length > 0 && !!document.querySelector('main[data-view]')`, 150000)); };
const frameBox = (selector, pick = 'els[0]') => p.evaluate(`(() => { const f = document.querySelector('iframe.queen27-specs-frame'); const d = f.contentDocument; const els = [...d.querySelectorAll(${JSON.stringify(selector)})].filter((e) => e.getBoundingClientRect().width > 0); const e = ${pick}; if (!e) return null; e.scrollIntoView({ block: 'center' }); const fr = f.getBoundingClientRect(); const r = e.getBoundingClientRect(); return { x: fr.left + r.left + Math.min(30, r.width / 2), y: fr.top + r.top + r.height / 2, href: e.getAttribute('href'), label: e.getAttribute('aria-label') || e.textContent.trim().slice(0, 60) } })()`);
const url = (tag, hash, lang = 'en') => `${origin}/?lang=${lang}&n=${nonce}${tag}#/queen?${hash}`;

try {
  // ── Ids, from the catalogs this build serves ──
  if (!(await shell(url('0', 'tab=map')))) report(2, { couldNotRun: 'the Queen shell never rendered' });
  const ids = await p.evaluate(`Promise.all(['skills/manifest.json', 'crons/manifest.json', 'agents/spec-agents.json', 'functions/spec-functions.json', 'tools/spec-tools.json', 't27/manifest.json', 'docs/system-docs.json'].map((u) => fetch(u).then((r) => r.json()))).then(([s, c, a, f, t, m, d]) => {
    const skillIds = s.skills.map((x) => x.id);
    const holder = a.agents.find((x) => x.letter !== a.agents[0].letter && (x.skills || []).some((k) => k.ok && k.id !== s.featured));
    return {
      skillIds, chapters: Object.fromEntries(d.chapters.map((ch) => [ch.stem, ch.order])),
      defaults: { agents: a.agents[0].letter, specs: 'specs/demos/hello_world.t27', project: d.chapters[0].stem },
      other: { skills: skillIds.find((x) => x !== s.featured), crons: c.crons.map((x) => x.id).find((x) => x !== c.featured), agents: a.agents[1].letter, functions: f.functions[1].id, tools: t.tools[1].id,
        specs: m.specs.some((x) => x.path === 'specs/tri/agent/agents.t27') ? 'specs/tri/agent/agents.t27' : m.specs.find((x) => !x.featured && x.path !== 'specs/demos/hello_world.t27').path, project: d.chapters[1].stem },
      chip: holder ? { agent: holder.letter, skill: holder.skills.find((k) => k.ok && k.id !== s.featured).id } : null,
    } })`);
  chapterOrder = ids.chapters;

  // A. A deep link opens the named card in every embedded Explorer.
  for (const kind of Object.keys(KEY)) {
    const id = ids.other[kind];
    const shown = (await shell(url(`a${kind}`, `tab=${kind}&${KEY[kind]}=${encodeURIComponent(id)}`))) && (await waitShows(kind, id));
    const t = await top();
    record(`A a deep link opens ${kind} ${id}`, shown && t.view === kind && t.params[KEY[kind]] === id, { top: t, frame: await frame() });
  }

  // B. A pick inside the frame writes the Queen address (replace), and a reload keeps it.
  await shell(url('b', 'tab=skills'));
  await p.until(`(() => { const f = ${FRAME}; return f && f.route === 'skills' && f.current.length > 0 })()`, 120000); await wait(1500);
  const before = await top();
  const box = await frameBox('button[aria-label]', `els.filter((b) => b.getAttribute('aria-current') !== 'true' && ${JSON.stringify(ids.skillIds)}.some((s) => s !== ${JSON.stringify(ids.other.skills)} && b.getAttribute('aria-label').endsWith(' — ' + s)))[3]`);
  const clicked = box ? box.label.split(' — ').pop() : null;
  const wasShown = clicked ? await nowShows('skills', clicked) : true;
  if (box) await p.clickAt(box.x, box.y);
  const picked = clicked && (await waitShows('skills', clicked, 60000)) && (await p.until(`(${TOP}).params.skill === ${JSON.stringify(clicked)}`, 20000));
  const after = await top();
  record('B a pick inside the skills frame writes skill= to the Queen address without a history entry', !!picked && !wasShown && after.params.tab === 'skills' && after.histLen === before.histLen, { clicked, before, after, frame: await frame() });
  await p.reload(); await p.until(`!!document.querySelector('main[data-view]')`, 150000);
  record('B a reload keeps the picked skill', !!clicked && (await waitShows('skills', clicked)) && (await top()).params.skill === clicked, { clicked, top: await top(), frame: await frame() });

  // C. An address changed from outside moves the frame, and Back moves it back.
  const target = ids.other.skills;
  const targetWasShown = await nowShows('skills', target);
  await p.evaluate(`void (location.hash = ${JSON.stringify(`#/queen?tab=skills&skill=${encodeURIComponent(target)}`)})`);
  record('C an outside hash change moves the skills frame', !targetWasShown && (await waitShows('skills', target, 60000)), { target, top: await top(), frame: await frame() });
  await p.evaluate('void history.back()');
  const back = !!clicked && (await waitShows('skills', clicked, 60000));
  record('C Back returns the Queen address and the frame to the earlier skill', back && (await top()).params.skill === clicked, { clicked, top: await top(), frame: await frame() });

  // D. The HUD language toggle keeps the card, and the address names the new language.
  const f0 = await frame();
  await p.evaluate(`void document.querySelector('button[data-tool="lang"]').click()`);
  const relang = await p.until(`(() => { const f = ${FRAME}; return f && f.lang === 'ru' && f.current.length > 0 })()`, 120000); await wait(1500);
  const tD = await top();
  record('D the language toggle keeps the picked skill in the frame and the address', !!relang && f0?.lang === 'en' && (await nowShows('skills', clicked)) && tD.params.skill === clicked, { clicked, before: f0, after: await frame(), top: tD });
  const searchLang = new URLSearchParams(tD.search).get('lang');
  await p.reload(); await p.until(`!!document.querySelector('main[data-view]')`, 150000); await wait(2000);
  const tD2 = await top();
  record('D the language toggle writes ?lang= to the address, and a reload keeps the language', searchLang === 'ru' && tD.lang === 'ru' && tD2.lang === 'ru', { searchAfterToggle: tD.search, langAfterToggle: tD.lang, afterReload: { search: tD2.search, lang: tD2.lang } });

  // E. A ladder link inside the agents frame switches the Queen tab.
  await shell(url('e', 'tab=agents'));
  await p.until(`(() => { const f = ${FRAME}; return f && f.route === 'agents' && f.current.length > 0 && !!document.querySelector('iframe.queen27-specs-frame').contentDocument.querySelector('.spec-x-ladder a[href^="#/skills"]') })()`, 120000); await wait(1000);
  const beforeE = await top();
  const ladder = await frameBox('.spec-x-ladder a[href^="#/skills"]');
  if (ladder) await p.clickAt(ladder.x, ladder.y);
  await p.until(`(() => { const t = ${TOP}; const f = ${FRAME}; return t.view === 'skills' && f && f.route === 'skills' && f.current.length > 0 })()`, 90000); await wait(1500);
  const tE = await top(), fE = await frame();
  record('E the ladder link Skills in the agents frame switches the Queen to SKILLS (rail, address, title, frame agree)', !!ladder && beforeE.view === 'agents' && tE.params.tab === 'skills' && tE.view === 'skills' && tE.active === 'skills' && fE?.title === TITLE.skills && fE?.route === 'skills' && tE.frames === 1, { ladder, before: beforeE, top: tE, frame: fE });

  // F. A skill chip inside an agent card opens that skill in the SKILLS tab.
  const chip = ids.chip;
  const onAgent = !!chip && (await shell(url('f', `tab=agents&agent=${chip.agent}`))) && (await waitShows('agents', chip.agent));
  const chipBox = onAgent ? await frameBox(`a[href*="#/skills?skill=${encodeURIComponent(chip.skill)}"]`) : null;
  if (chipBox) await p.clickAt(chipBox.x, chipBox.y);
  const opened = !!chipBox && (await waitShows('skills', chip.skill, 90000));
  const tF = await top();
  record('F a skill chip in an agent card opens that skill in the SKILLS tab and names it in the address', opened && tF.params.tab === 'skills' && tF.params.skill === chip.skill && tF.active === 'skills', { chip, onAgent, chipBox, top: tF, frame: await frame() });

  // G. A PROJECT chapter jump is in the address and survives a reload.
  await shell(url('g', 'tab=project'));
  await waitShows('project', ids.defaults.project); await wait(1000);
  const rulesWasShown = await nowShows('project', 'rules');
  await p.evaluate(`[...document.querySelectorAll('button.queen27-docs-jump')].find((b) => /Rules/.test(b.textContent)).click()`);
  const jumped = await waitShows('project', 'rules', 60000);
  record('G a PROJECT jump writes chapter= to the address', !rulesWasShown && jumped && (await top()).params.chapter === 'rules', { top: await top(), frame: await frame() });
  await p.reload(); await p.until(`!!document.querySelector('main[data-view]')`, 150000);
  const kept = await waitShows('project', 'rules');
  const tG = await top();
  record('G a reload keeps the chapter and its jump', kept && /Rules/.test(tG.jump || ''), { top: tG, frame: await frame() });

  // H. The Spec Explorer frame follows an outside address change.
  const onOther = (await shell(url('h', `tab=specs&spec=${encodeURIComponent(ids.other.specs)}`))) && (await waitShows('specs', ids.other.specs, 150000));
  await p.evaluate(`void (location.hash = ${JSON.stringify(`#/queen?tab=specs&spec=${encodeURIComponent(ids.defaults.specs)}`)})`);
  const moved = await waitShows('specs', ids.defaults.specs, 90000);
  record('H an outside hash change moves the specs frame', onOther && moved, { from: ids.other.specs, to: ids.defaults.specs, top: await top(), frame: await frame() });

  // I. A refused id falls back to the default, the address takes the default, and a valid id then opens.
  const errorsBefore = p.errors.length;
  await shell(url('i', 'tab=agents&agent=%3Cx%3E'));
  const fellBack = await waitShows('agents', ids.defaults.agents);
  const rewritten = await p.until(`(${TOP}).params.agent === ${JSON.stringify(ids.defaults.agents)}`, 30000);
  await p.evaluate(`void (location.hash = ${JSON.stringify(`#/queen?tab=agents&agent=${ids.other.agents}`)})`);
  const validOpens = await waitShows('agents', ids.other.agents, 60000);
  record('I a refused agent id falls back to the default in the frame and the address, without an exception, and a valid one then opens', fellBack && !!rewritten && validOpens && p.errors.length === errorsBefore, { errors: p.errors.slice(errorsBefore), top: await top(), frame: await frame() });

  // K. An address that names no card of its tab takes the frame's card, so a reload opens what was on screen.
  const onCron = (await shell(url('k', `tab=crons&cron=${encodeURIComponent(ids.other.crons)}`))) && (await waitShows('crons', ids.other.crons));
  await p.evaluate(`void (location.hash = '#/queen?tab=crons')`);
  const tookCard = await p.until(`(${TOP}).params.cron === ${JSON.stringify(ids.other.crons)}`, 30000);
  const stillShown = await nowShows('crons', ids.other.crons);
  await p.reload(); await p.until(`!!document.querySelector('main[data-view]')`, 150000);
  const afterReload = await waitShows('crons', ids.other.crons);
  record('K an outside change to the bare tab keeps the address and the frame on one card, and a reload opens it', onCron && !!tookCard && stillShown && afterReload, { cron: ids.other.crons, top: await top(), frame: await frame() });

  // L. Ids the helpers accept but the catalogs do not hold.
  await shell(url('l1', 'tab=project&chapter=zz-no-such-chapter'));
  const firstChapter = await waitShows('project', ids.defaults.project);
  const chapterCorrected = await p.until(`(${TOP}).params.chapter === ${JSON.stringify(ids.defaults.project)}`, 30000);
  record('L an unknown chapter opens the first one, and the address names the chapter on show', firstChapter && !!chapterCorrected, { top: await top(), frame: await frame() });
  const errorsL = p.errors.length;
  await shell(url('l2', 'tab=skills&skill=t27%2Fzz-no-such-skill'));
  const notFound = await p.until(`(() => { const f = ${FRAME}; return f && f.route === 'skills' && f.params.skill === 't27/zz-no-such-skill' && f.notFound && f.current.length === 0 })()`, 120000);
  await wait(3000);
  const tL = await top();
  record('L an unknown skill shows the Skill Explorer\'s own not-found card, not a different skill, and the address keeps the id', !!notFound && tL.params.skill === 't27/zz-no-such-skill' && p.errors.length === errorsL, { top: tL, frame: await frame(), errors: p.errors.slice(errorsL) });

  // J. Tab switches add no history entries and drop the old tab's card; Back after an
  //    outside navigation lands on the tab with its Explorer in the frame.
  await shell(url('j', `tab=skills&skill=${encodeURIComponent(ids.other.skills)}`));
  await waitShows('skills', ids.other.skills); await wait(1000);
  const h0 = (await top()).histLen;
  for (const v of ['crons', 'agents']) {
    await p.evaluate(`document.querySelector('button.queen27-hud-cmd[data-view="${v}"]').click()`);
    await p.until(`(() => { const f = ${FRAME}; return f && f.route === '${v}' })()`, 120000); await wait(1000);
  }
  const tJ1 = await top();
  await p.evaluate(`void (location.hash = '#/queen?tab=map')`); await p.until(`(${TOP}).view === 'map'`, 30000); await wait(800);
  await p.evaluate('void history.back()');
  await p.until(`(${TOP}).params.tab === 'agents'`, 30000); await p.until(`(() => { const f = ${FRAME}; return f && f.route === 'agents' })()`, 90000); await wait(1500);
  const tJ = await top(), fJ = await frame();
  record('J tab switches add no history entries and drop the old card, and Back after an outside navigation returns to the tab and its Explorer', tJ1.histLen === h0 && tJ1.params.skill === undefined && tJ.params.tab === 'agents' && tJ.view === 'agents' && fJ?.route === 'agents' && fJ?.title === TITLE.agents, { h0, afterSwitches: tJ1, top: tJ, frame: fJ });

  record('no uncaught exceptions', p.errors.length === 0, { errors: p.errors.slice(0, 8) });
} catch (e) {
  clearTimeout(deadline);
  report(2, { couldNotRun: String(e?.message || e) });
}
clearTimeout(deadline);
report(checks.some((c) => !c.ok) ? 1 : 0);
