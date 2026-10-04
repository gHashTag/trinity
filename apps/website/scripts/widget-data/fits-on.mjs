#!/usr/bin/env node
// fits-on.mjs -- the data behind public/widgets/fits-on/: the XC7A200T's totals as nextpnr-xilinx
// itself printed them, and two real designs to try the arithmetic on.
//
// nextpnr-xilinx prints a "Device utilisation:" block after packing: one line per BEL type,
// `TYPE: used/total pct%`. This reads that block from two real place-and-route runs of the ALINX
// AX7203 board (part xc7a200tfbg484-2; NOT the QMTech Wukong, whose package is fgg676), checks
// that both runs print the same totals for every BEL type, and writes device.json with each log's
// path, size and sha256. If the two logs disagree on any total it stops and writes nothing.
//
// The logs carry no version line, so the nextpnr-xilinx version is read from the manifest.json the
// build script wrote beside each log, and named as coming from there.
//
// For each run it also reads the yosys stat block (LUT1..LUT6, INV, FD*, RAMB*, DSP48E1 cells)
// from yosys.full.log beside the log, so the page can show a synthesis count next to the placed
// count, and, where node_routed.json exists, counts the LUT6 positions (slice letter A-D) the
// placed LUT cells occupy.
//
// It then reads specs/widgets/fits-on.t27 and stops if a K_ total or an example count there is not
// the number parsed here, so the spec cannot drift from the logs.
//
//   node scripts/widget-data/fits-on.mjs           write public/widgets/fits-on/device.json
//   node scripts/widget-data/fits-on.mjs --check   parse and compare, write nothing
import { createHash } from 'node:crypto'
import { existsSync, readFileSync, statSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const SITE = join(dirname(fileURLToPath(import.meta.url)), '..', '..')
const OUT = join(SITE, 'public/widgets/fits-on/device.json')
const SPEC = join(SITE, 'specs/widgets/fits-on.t27')

// The two runs, read-only. `id` is the key the spec's K_EX_<ID> constants use.
const RUNS = [
  { id: 'node0', board: 'ALINX AX7203', dir: '/tmp/x7board/node0', routed: 'node_routed.json' },
  { id: 'tnf16', board: 'ALINX AX7203', dir: '/Users/playra/trinity-fpga/build/tnf16_board_ax7203', routed: null },
]
// BEL types the page divides by, and the order of the spec's K_EX_* arrays.
const USED_KEYS = ['SLICE_LUTX', 'SLICE_FFX', 'DSP48E1', 'RAMB36E1', 'RAMB18E1']

const sha256 = (b) => createHash('sha256').update(b).digest('hex')
// Paths are published with the home directory written as ~.
const HOME = process.env.HOME || ''
const tilde = (p) => (HOME && p.startsWith(HOME + '/') ? '~' + p.slice(HOME.length) : p)

/** The "Device utilisation:" block: { TYPE: [used, total, printed percent] } in log order. */
export function parseUtilisation(text) {
  const at = text.indexOf('Info: Device utilisation:')
  if (at < 0) throw new Error('no "Device utilisation:" block')
  const rows = {}
  for (const line of text.slice(at).split('\n').slice(1)) {
    const m = line.match(/^Info:\s+([A-Za-z0-9_]+):\s+(\d+)\/\s*(\d+)\s+(\d+)%\s*$/)
    if (!m) break
    if (m[1] in rows) throw new Error(`BEL type ${m[1]} twice in one block`)
    rows[m[1]] = [Number(m[2]), Number(m[3]), Number(m[4])]
  }
  if (Object.keys(rows).length < 10) throw new Error(`only ${Object.keys(rows).length} rows in the block`)
  return rows
}

/** The last yosys `stat` cell list in a log: { CELLTYPE: count }. */
export function parseYosysStat(text) {
  const blocks = [...text.matchAll(/^\s+(\d+) cells\n((?:\s+\d+\s+\S+\n)+)/gm)]
  if (!blocks.length) throw new Error('no yosys stat block')
  const out = {}
  for (const m of blocks.at(-1)[2].matchAll(/^\s+(\d+)\s+(\S+)$/gm)) out[m[2]] = Number(m[1])
  return out
}

function lutPositions(routedPath) {
  const j = JSON.parse(readFileSync(routedPath, 'utf8'))
  const cells = new Set(), positions = new Set(), bels = new Set()
  for (const mod of Object.values(j.modules)) {
    for (const [name, c] of Object.entries(mod.cells)) {
      const bel = c.attributes?.NEXTPNR_BEL
      if (c.type !== 'SLICE_LUTX' || !bel) continue
      const [site, b] = bel.split('/')
      cells.add(name)
      bels.add(bel)
      positions.add(`${site}/${b[0]}`)
    }
  }
  return { lut_cells: cells.size, lut_bels: bels.size, lut6_positions: positions.size }
}

function readRun(run) {
  const logPath = join(run.dir, 'nextpnr.log')
  const logBytes = readFileSync(logPath)
  const log = logBytes.toString('utf8')
  const util = parseUtilisation(log)
  const version = (log.match(/Version\s+([0-9][^\s)]*)/) ?? [])[1] ?? null
  const manPath = join(run.dir, 'manifest.json')
  const manBytes = readFileSync(manPath)
  const man = JSON.parse(manBytes.toString('utf8'))
  const yosysPath = join(run.dir, 'yosys.full.log')
  const yosysBytes = readFileSync(yosysPath)
  const stat = parseYosysStat(yosysBytes.toString('utf8'))
  const sum = (re) => Object.entries(stat).filter(([k]) => re.test(k)).reduce((a, [, v]) => a + v, 0)
  const out = {
    id: run.id,
    board: run.board,
    top: man.top,
    part: man.part,
    chipdb: tilde(man.chipdb),
    nextpnr_log: { path: tilde(logPath), bytes: logBytes.length, sha256: sha256(logBytes) },
    nextpnr_version_in_log: version,
    nextpnr_version_in_manifest: man.tools?.['nextpnr-xilinx'] ?? null,
    nextpnr_version: ((man.tools?.['nextpnr-xilinx'] ?? '').match(/Version\s+([^\s)]+)/) ?? [])[1] ?? null,
    manifest: { path: tilde(manPath), sha256: sha256(manBytes) },
    yosys_log: { path: tilde(yosysPath), bytes: yosysBytes.length, sha256: sha256(yosysBytes) },
    nextpnr_cmd: man.steps?.find((s) => s.step === 'nextpnr')?.cmd?.map(tilde).join(' ') ?? null,
    used: Object.fromEntries(USED_KEYS.map((k) => [k, util[k]?.[0] ?? 0])),
    // The percent nextpnr printed for SLICE_LUTX: used over LUT BELs, rounded down.
    lut_pct_printed: util.SLICE_LUTX?.[2] ?? null,
    yosys: { LUT: sum(/^LUT[1-6]$/), INV: stat.INV ?? 0, FF: sum(/^FD[A-Z]{2}$/), RAMB36E1: stat.RAMB36E1 ?? 0, RAMB18E1: stat.RAMB18E1 ?? 0, DSP48E1: stat.DSP48E1 ?? 0 },
    util,
  }
  if (run.routed && existsSync(join(run.dir, run.routed))) {
    const p = join(run.dir, run.routed)
    out.routed = { path: tilde(p), bytes: statSync(p).size, sha256: sha256(readFileSync(p)), ...lutPositions(p) }
  }
  return out
}

/** Copies of one design that fit, per resource, at 100% of each; null when the design uses none. */
export function fits(used, cap) {
  const per = {
    LUT: used.SLICE_LUTX ? Math.floor(cap.LUT / used.SLICE_LUTX) : null,
    FF: used.SLICE_FFX ? Math.floor(cap.FF / used.SLICE_FFX) : null,
    DSP: used.DSP48E1 ? Math.floor(cap.DSP / used.DSP48E1) : null,
    BRAM: (2 * used.RAMB36E1 + used.RAMB18E1) ? Math.floor(cap.BRAM18 / (2 * used.RAMB36E1 + used.RAMB18E1)) : null,
  }
  const known = Object.entries(per).filter(([, v]) => v !== null)
  const copies = Math.min(...known.map(([, v]) => v))
  return { per, copies, binding: known.filter(([, v]) => v === copies).map(([k]) => k) }
}

function specConsts(text) {
  const out = {}
  for (const [, name, value] of text.matchAll(/^pub const (K_\w+) : [^=]+= (.*);$/gm)) {
    try { out[name] = JSON.parse(value) } catch { /* str or expression: not a number we check */ }
  }
  return out
}

function main() {
  const check = process.argv.includes('--check')
  const runs = RUNS.map(readRun)
  // The two logs must agree on every total, and list the same BEL types.
  const [a, b] = runs
  const types = new Set([...Object.keys(a.util), ...Object.keys(b.util)])
  const disagree = [...types].filter((t) => a.util[t]?.[1] !== b.util[t]?.[1])
  if (disagree.length) {
    console.error(`fits-on: the two logs disagree on the totals of ${disagree.map((t) => `${t} (${a.util[t]?.[1]} vs ${b.util[t]?.[1]})`).join(', ')}; nothing written`)
    process.exit(1)
  }
  const totals = Object.fromEntries(Object.entries(a.util).map(([k, v]) => [k, v[1]]))
  const capacity = { LUT: totals.SLICE_LUTX / 2, LUT_BELS: totals.SLICE_LUTX, FF: totals.SLICE_FFX, DSP: totals.DSP48E1, BRAM18: totals.RAMB18E1, RAMB36: totals.RAMB36E1 }
  if (!Number.isInteger(capacity.LUT) || capacity.BRAM18 !== 2 * capacity.RAMB36) {
    console.error('fits-on: LUT BELs not even, or RAMB18E1 is not twice RAMB36E1; the page arithmetic assumes both')
    process.exit(1)
  }
  const examples = runs.map((r) => {
    const { util, ...rest } = r
    return { ...rest, fits: fits(r.used, capacity), fits_bels: fits(r.used, { ...capacity, LUT: capacity.LUT_BELS }) }
  })
  const data = {
    t27: 'fits-on/1',
    device: 'xc7a200t',
    note: 'Totals are the "Device utilisation" totals nextpnr-xilinx printed in both logs; the logs agree on every BEL type.',
    totals,
    capacity,
    examples,
    written_by: 'node scripts/widget-data/fits-on.mjs',
  }

  // The spec's numbers must be these numbers.
  const k = specConsts(readFileSync(SPEC, 'utf8'))
  const want = {
    K_SLICE_LUTX: totals.SLICE_LUTX, K_SLICE_FFX: totals.SLICE_FFX, K_CARRY4: totals.CARRY4,
    K_DSP48E1: totals.DSP48E1, K_RAMB36E1: totals.RAMB36E1, K_RAMB18E1: totals.RAMB18E1, K_PAD_FBG484: totals.PAD,
  }
  for (const ex of examples) {
    const key = `K_EX_${ex.id.toUpperCase()}`
    want[key] = USED_KEYS.map((u) => ex.used[u])
    want[`${key}_COPIES`] = ex.fits.copies
    want[`${key}_COPIES_BELS`] = ex.fits_bels.copies
    want[`${key}_YOSYS_LUT`] = ex.yosys.LUT
  }
  const node0 = examples.find((e) => e.id === 'node0')
  if (node0.routed) want.K_EX_NODE0_LUT6_POSITIONS = node0.routed.lut6_positions
  const bad = Object.entries(want).filter(([name, v]) => JSON.stringify(k[name]) !== JSON.stringify(v))
  if (bad.length) {
    console.error(`fits-on: ${SPEC} does not match the logs:`)
    for (const [name, v] of bad) console.error(`  ${name} is ${JSON.stringify(k[name])}, the logs say ${JSON.stringify(v)}`)
    process.exit(1)
  }

  if (!check) writeFileSync(OUT, JSON.stringify(data, null, 1) + '\n')
  console.log(`fits-on: ${check ? 'checked' : 'wrote ' + OUT}; totals agree in both logs (${Object.keys(totals).length} BEL types): ` +
    `SLICE_LUTX ${totals.SLICE_LUTX}, SLICE_FFX ${totals.SLICE_FFX}, CARRY4 ${totals.CARRY4}, DSP48E1 ${totals.DSP48E1}, RAMB36E1 ${totals.RAMB36E1}, RAMB18E1 ${totals.RAMB18E1}, PAD ${totals.PAD}`)
  for (const e of examples) {
    console.log(`  ${e.id} (${e.top}, ${e.part}): used ${USED_KEYS.map((u) => `${u} ${e.used[u]}`).join(', ')}; yosys LUT1-6 ${e.yosys.LUT}, INV ${e.yosys.INV}, FF ${e.yosys.FF}` +
      `${e.routed ? `; routed: ${e.routed.lut_cells} LUT cells on ${e.routed.lut6_positions} LUT6 positions` : ''}` +
      `; fits ${e.fits.copies} (binding ${e.fits.binding.join('+')}), ${e.fits_bels.copies} if divided by LUT BELs; nextpnr ${e.nextpnr_version_in_log ?? 'version not in log; manifest: ' + e.nextpnr_version_in_manifest}`)
  }
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) main()
