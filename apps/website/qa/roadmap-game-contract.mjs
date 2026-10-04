// The rules of LEVEL II (src/lib/roadmapGame.ts), held by example.
//
// The one rule that crosses a repository boundary is the raid: this page and
// gHashTag/t27 tools/queen/feed_roadmap.py must name the same sector on the
// same UTC day, or the board says "raid" over a sector the feeder is not
// feeding first. The feeder pins RAID_STAGES = (1, 2, 5, 6, 7) in its own
// self-test; this contract pins the same list out of goals.json.

import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import {
  BOSS_OPENS_AT,
  builtShareBelow,
  crackedTargets,
  honeyOf,
  msToNextDay,
  parsePortTitle,
  pulsePhase,
  raidOf,
  raidStages,
  rowsFor,
  targetOf,
  utcDay,
} from '../src/lib/roadmapGame.ts'

const goals = JSON.parse(readFileSync(new URL('../public/roadmap/goals.json', import.meta.url), 'utf8')).goals

// The raid: the same list and the same formula as the feeder.
assert.deepEqual(raidStages(goals), [1, 2, 5, 6, 7], 'raid stages drifted from feed_roadmap.py RAID_STAGES')
const day = 20358 // 2025-09-27 UTC
assert.equal(utcDay(Date.UTC(2025, 8, 27, 23, 59)), day)
assert.equal(raidOf(goals, day), [1, 2, 5, 6, 7][day % 5])
assert.deepEqual(
  [0, 1, 2, 3, 4].map((k) => raidOf(goals, day + k)).sort(),
  [1, 2, 5, 6, 7],
  'five days visit every raidable stage once',
)
assert.equal(raidOf([{ stage: 8 }, { stage: 3, locked: { en: 'x', ru: 'x' } }], day), null)
assert.equal(msToNextDay(Date.UTC(2025, 8, 27, 23, 0)), 3_600_000)

// Honey: functions of built and cracked cells; raid cells closed today count twice.
const now = Date.UTC(2025, 8, 27, 12)
const today = new Date(now).toISOString()
const yesterday = new Date(now - 86_400_000).toISOString()
const tasks = [
  { stage: 1, units: 2, state: 'built', closedAt: today },
  { stage: 1, units: 3, state: 'built', closedAt: yesterday },
  { stage: 2, units: 5, state: 'cracked', closedAt: today },
  { stage: 2, units: 7, state: 'target' },
  { stage: 5, units: 1, state: 'building' },
]
assert.equal(honeyOf(tasks, 1, utcDay(now)), 2 * 2 + 3 + 5)
assert.equal(honeyOf(tasks, null, utcDay(now)), 2 + 3 + 5)

// Bosses open on half of the comb below them.
assert.equal(BOSS_OPENS_AT, 0.5)
assert.equal(builtShareBelow(tasks), 3 / 5)
assert.equal(builtShareBelow([{ stage: 9, units: 1, state: 'built' }]), 0, 'the endgame is not below the bosses')
assert.equal(builtShareBelow([]), 0)

// A port task's target, from both title shapes the feeders write.
assert.equal(
  targetOf('Port tools/check_x.py (Python, 4 functions) to specs/port/tools/check_x.t27'),
  'specs/port/tools/check_x.t27',
)
assert.equal(
  targetOf('Port part 1 of 2 of tools/y.py to specs/port/tools/y.t27 (8 functions)'),
  'specs/port/tools/y.t27',
)
assert.equal(targetOf('Implement the 8 empty function bodies in specs/vsa/packed_vsa.t27'), null)

// Cracks: defects that name a port file; a port task naming its own target is not one.
const cracks = crackedTargets([
  'Port tools/a.py (Python, 1 function) to specs/port/tools/a.t27',
  'Implement the 1 empty function body in specs/port/tools/b.t27',
  'specs/port/trinity/src/vm/opcodes.t27: test-report BLOCKED on master',
])
assert.deepEqual([...cracks].sort(), ['specs/port/tools/b.t27', 'specs/port/trinity/src/vm/opcodes.t27'])

// The round's pulse, from the board's own numbers.
assert.equal(pulsePhase(new Date(now - 30_000).toISOString(), 60, now), 0.5)
assert.equal(pulsePhase(new Date(now - 90_000).toISOString(), 60, now), 0.5, 'a missed round wraps, it does not overflow')
assert.equal(pulsePhase(null, 60, now), null)
assert.equal(pulsePhase(today, 0, now), null)
assert.equal(pulsePhase('not a time', 60, now), null)

// Titles: the stage-1 shape, the cross-repository shape, and a count-less title.
assert.deepEqual(parsePortTitle('Port tools/toolbelt.py (Python, 5 functions) to specs/port/tools/toolbelt.t27'), {
  repo: 'gHashTag/t27', path: 'tools/toolbelt.py', lang: 'Python', units: 5,
})
assert.deepEqual(
  parsePortTitle('Port gHashTag/BrowserOS:trios/a/queen-lease.ts (TypeScript, 6 functions) to specs/port/browseros/trios/a/queen-lease.t27'),
  { repo: 'gHashTag/BrowserOS', path: 'trios/a/queen-lease.ts', lang: 'TypeScript', units: 6 },
)
assert.deepEqual(parsePortTitle('Port fpga/vivado/blinky.v (Verilog, 1 module) to specs/port/fpga/vivado/blinky.t27'), {
  repo: 'gHashTag/t27', path: 'fpga/vivado/blinky.v', lang: 'Verilog', units: 1,
})
assert.equal(parsePortTitle('Port part 1 of 2 of tools/y.py to specs/port/tools/y.t27').units, 4, 'no count reads as middling')
assert.equal(parsePortTitle('Implement something'), null)

// The comb: apex-down rows hold 1, 2, 3 ... cells; 9 rows at least, 16 at most.
assert.equal(rowsFor(1), 9)
assert.equal(rowsFor(45), 9)
assert.equal(rowsFor(46), 10)
assert.equal(rowsFor(10_000), 16)

console.log('roadmap-game contract: raid, honey, bosses, cracks, pulse, titles and rows hold')
