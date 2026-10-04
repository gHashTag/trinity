import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const h = await import('../src/components/queenHiveDisplay.ts');
assert.equal(typeof h.hiveTaskPaint, 'function', 'RED: occupied cells have no shared task-status fill');
const task = (state, coverage = 'unknown') => ({ state, coverage });
for (const state of ['backlog', 'open', '', 'unexpected']) {
  assert.equal(h.hiveTaskPaint(task(state)).tone, 'problem', `${state || 'missing'} starts red`);
}
for (const state of ['running', 'review']) {
  assert.equal(h.hiveTaskPaint(task(state)).tone, state==='review'?'review':'active');
  assert.equal(h.hiveTaskPaint(task(state, 't27')).tone, state==='review'?'review':'active', 'reopened work loses honey');
}
for (const state of ['done', 'closed']) {
  for (const coverage of ['unknown', 'manual', 'awaiting']) {
    assert.equal(h.hiveTaskPaint(task(state, coverage)).tone, 'problem', 'closure alone is not T27');
    assert.equal(h.hiveTaskPaint(task(state, coverage)).reason, 'proof');
  }
  assert.equal(h.hiveTaskPaint(task(state, 't27')).tone, 'honey', 'test-only proof input; current ledger stays unknown');
}
assert.equal(h.hiveTaskPaint(task('blocked', 't27')).tone, 'blocked');
assert.equal(h.hiveTaskPaint(null), null, 'hub and vacant cells have no task fill');
const rows = [null, task('backlog'), task('running'), task('review'), task('closed'), task('done', 't27')];
assert.deepEqual(h.hiveTaskCounts(rows), { problem: 2, blocked: 0, active: 1, review: 1, paused: 0, honey: 1 });
assert.deepEqual(h.hiveTaskCounts([]), { problem: 0, blocked: 0, active: 0, review: 0, paused: 0, honey: 0 });
const identity = { key: 'gHashTag/trios#7', ...task('backlog') };
assert.notEqual(h.hiveDisplayPaintKey([identity]), h.hiveDisplayPaintKey([{ ...identity, state: 'running' }]), 'same identity poll invalidates GPU fill');
assert.notEqual(h.hiveDisplayPaintKey([{ ...identity, state: 'done' }]), h.hiveDisplayPaintKey([{ ...identity, state: 'done', coverage: 't27' }]), 'coverage transition invalidates GPU fill');
assert.equal(h.hiveDisplayPaintKey([identity]), h.hiveDisplayPaintKey([{ ...identity, title: 'Renamed' }]), 'text-only update need not rebuild GPU');
assert.notEqual(h.hiveDisplayPaintKey([identity]), h.hiveDisplayPaintKey([null]), 'removed issue clears its fill');
const scene = readFileSync(new URL('../src/components/QueenCombBabylon.tsx', import.meta.url), 'utf8');
const card = readFileSync(new URL('../src/components/QueenHiveDisplays.tsx', import.meta.url), 'utf8');
const css = readFileSync(new URL('../src/pages/Queen.css', import.meta.url), 'utf8');
assert.match(scene, /hiveDisplayPaintKey\(displays\)/, 'render invalidation uses current task paint');
assert.match(scene, /hiveTaskPaint\(displaysRef.current\[i\]\)/);
assert.match(scene, /thinInstanceSetBuffer\("matrix"/, 'all occupied cells render in palette batches');
assert.match(card, /data-task-tone=\{paint.tone\}/, 'native close-up uses the same status');
assert.match(card, /hiveTaskCounts\(rows\)/, 'whole-project counts include offscreen cells');
assert.match(css, /--hive-task-rgb/, 'native status fills use the shared palette');
console.log('Hive status fill: PASS (default red, live blue, proof-gated honey, nulls, counts, polling invalidation)');
