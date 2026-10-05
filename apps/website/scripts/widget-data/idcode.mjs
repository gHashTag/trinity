#!/usr/bin/env node
// idcode.mjs -- the data behind public/widgets/idcode/: openFPGALoader's own device table, and
// what the JTAG chain on our bench answered.
//
// openFPGALoader (github.com/trabucayre/openFPGALoader, Apache-2.0, Copyright (C) 2019 Gwenhael
// Goavec-Merou) keeps every IDCODE it knows in src/part.hpp: fpga_list (manufacturer, family,
// model, IR length), misc_dev_list (other TAPs it can step over) and list_manufacturer (the JEDEC
// codes it names). src/board.hpp names the FPGA part of each board it knows. This reads both files
// at one pinned commit -- the v1.1.1 tag, the same version Homebrew installed on the bench Mac -- and
// refuses files whose sha256 is not the one recorded below, so a rerun gives the same JSON.
//
// The map in part.hpp is a std::map built from an initializer list: when a key appears twice the
// FIRST row is kept and the second is silently dropped. The JSON keeps the first row and lists the
// dropped ones as `shadowed`, so the page can say so.
//
//   node scripts/widget-data/idcode.mjs                  read the pinned files (gh api, read-only) and write parts.json
//   node scripts/widget-data/idcode.mjs --src DIR        read part.hpp and board.hpp from DIR instead
//   node scripts/widget-data/idcode.mjs --bench          also run `openFPGALoader -c digilent_hs2 --detect
//                                                       --verbose-level 2` and record the raw IDCODEs;
//                                                       without it the previous bench record is kept
import { createHash } from 'node:crypto'
import { execFileSync } from 'node:child_process'
import { existsSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const SITE = join(dirname(fileURLToPath(import.meta.url)), '..', '..')
const OUT = join(SITE, 'public/widgets/idcode/parts.json')
const SPEC = join(SITE, 'specs/widgets/idcode.t27')

const REPO = 'trabucayre/openFPGALoader'
const TAG = 'v1.1.1'
const COMMIT = '85be4fa02b2dd6a83716d7dfac3d25bbd260ff7b'
const FILES = {
  'src/part.hpp': '74ded91a5ef62d1fc5c95dba8a9c438b390b8fbf77ff228db4336490fac47e1b',
  'src/board.hpp': '0c955d02921affa5eaa15ab8b19f3ef37c9a3d57e729fca4ca29326169f31e86',
}

// Boards offered as presets: well-known ones whose part resolves to exactly one fpga_list row.
// The names are openFPGALoader's own board names (its -b argument).
const PRESET_BOARDS = ['arty_a7_35t', 'basys3', 'nexys_a7_100', 'nexysVideo', 'arty_s7_50', 'pynq_z2', 'zedboard', 'qmtechKintex7', 'alinx_ax7203']

const sha256 = (s) => createHash('sha256').update(s).digest('hex')
const hex8 = (n) => '0x' + (n >>> 0).toString(16).padStart(8, '0')

function readSource(rel, srcDir) {
  if (srcDir) return readFileSync(join(srcDir, rel.split('/').pop()), 'utf8')
  return execFileSync('gh', ['api', `repos/${REPO}/contents/${rel}?ref=${COMMIT}`, '-H', 'Accept: application/vnd.github.raw'], { encoding: 'utf8', maxBuffer: 1 << 22 })
}

function block(text, name) {
  const start = text.indexOf(name)
  if (start < 0) throw new Error(`part.hpp: ${name} not found`)
  const open = text.indexOf('{', text.indexOf('=', start))
  const close = text.indexOf('\n};', open)
  // Drop // and /* */ comments so a commented-out row is not read as a row.
  return text.slice(open, close).replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/[^\n]*/g, '')
}

export function parsePartHpp(text) {
  const fpga = []
  const shadowed = []
  const seen = new Set()
  const rowRe = /\{\s*0x([0-9a-fA-F]{1,8})\s*,\s*\{\s*"([^"]*)"\s*,\s*"([^"]*)"\s*,\s*"([^"]*)"\s*,\s*(\d+)\s*\}\s*\}/g
  for (const m of block(text, 'fpga_list').matchAll(rowRe)) {
    const row = [parseInt(m[1], 16) >>> 0, m[2], m[3], m[4], Number(m[5])]
    if (seen.has(row[0])) shadowed.push(row)
    else { seen.add(row[0]); fpga.push(row) }
  }
  const misc = [...block(text, 'misc_dev_list').matchAll(/\{\s*0x([0-9a-fA-F]{1,8})\s*,\s*\{\s*"([^"]*)"\s*,\s*(\d+)\s*\}\s*\}/g)]
    .map((m) => [parseInt(m[1], 16) >>> 0, m[2], Number(m[3])])
  // list_manufacturer keeps its comments: read them from the raw text, not the stripped block.
  const mfgStart = text.indexOf('list_manufacturer')
  const mfgText = text.slice(mfgStart, text.indexOf('\n};', mfgStart))
  const manufacturers = [...mfgText.matchAll(/\{\s*0x([0-9a-fA-F]{1,4})\s*,\s*"([^"]*)"\s*\}/g)].map((m) => [parseInt(m[1], 16), m[2]])
  const macro = (name) => (text.match(new RegExp(`#define\\s+${name}\\(_idcode\\)\\s+(.*)`)) ?? [])[1]?.trim()
  return { fpga, shadowed, misc, manufacturers, macros: { IDCODE2MANUFACTURERID: macro('IDCODE2MANUFACTURERID'), IDCODE2PART: macro('IDCODE2PART'), IDCODE2VERS: macro('IDCODE2VERS') } }
}

export function parseBoardHpp(text) {
  const out = new Map()
  for (const m of text.matchAll(/JTAG_(?:BITBANG_)?BOARD\(\s*"([^"]+)"\s*,\s*"([^"]*)"/g)) if (!out.has(m[1])) out.set(m[1], m[2])
  return out
}

/** The fpga_list rows whose model a board's part string starts with; the longest model wins. */
function rowForPart(part, fpga) {
  const p = part.toLowerCase()
  const hits = fpga.filter((r) => !/[/*]/.test(r[3]) && p.startsWith(r[3].toLowerCase()))
  if (!hits.length) return null
  const best = Math.max(...hits.map((r) => r[3].length))
  const top = hits.filter((r) => r[3].length === best)
  return top.length === 1 ? top[0] : null
}

function bench() {
  const args = ['-c', 'digilent_hs2', '--detect', '--verbose-level', '2']
  let out = ''
  try { out = execFileSync('openFPGALoader', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], timeout: 60000 }) } catch (e) { out = String(e.stdout ?? '') + String(e.stderr ?? '') }
  const version = execFileSync('openFPGALoader', ['--Version'], { encoding: 'utf8' }).trim()
  const raw = [...out.matchAll(/^- (\d+) -> 0x([0-9a-f]{8})$/gm)].map((m) => parseInt(m[2], 16) >>> 0).filter((v) => v !== 0xffffffff)
  const printed = [...out.matchAll(/^\s+idcode\s+0x([0-9a-f]+)$/gm)].map((m) => parseInt(m[1], 16) >>> 0)
  if (!raw.length) throw new Error(`--bench: no raw IDCODE in the openFPGALoader output:\n${out}`)
  return { date: new Date().toISOString().slice(0, 16) + 'Z', tool: version, command: `openFPGALoader ${args.join(' ')}`, raw: raw.map(hex8), printed: printed.map(hex8) }
}

function main() {
  const argv = process.argv.slice(2)
  const srcDir = argv.includes('--src') ? argv[argv.indexOf('--src') + 1] : null
  const partText = readSource('src/part.hpp', srcDir)
  const boardText = readSource('src/board.hpp', srcDir)
  const got = { 'src/part.hpp': sha256(partText), 'src/board.hpp': sha256(boardText) }
  for (const [rel, want] of Object.entries(FILES)) if (got[rel] !== want) throw new Error(`${rel}: sha256 ${got[rel]}, pinned ${want}; not the ${TAG} file`)

  const parsed = parsePartHpp(partText)
  const boards = parseBoardHpp(boardText)
  const presets = PRESET_BOARDS.map((b) => {
    const part = boards.get(b)
    if (!part) throw new Error(`board.hpp: no board ${b}`)
    const row = rowForPart(part, parsed.fpga)
    if (!row) throw new Error(`board ${b} (${part}): no single fpga_list row`)
    return [b, part, hex8(row[0])]
  })

  const prev = existsSync(OUT) ? JSON.parse(readFileSync(OUT, 'utf8')) : {}
  const benchRec = argv.includes('--bench') ? bench() : prev.bench
  if (!benchRec) throw new Error('no bench record yet: run once with --bench on the bench Mac')

  // The spec's own numbers must be what the table and the bench say.
  const spec = readFileSync(SPEC, 'utf8')
  const k = (name) => Number((spec.match(new RegExp(`pub const ${name} : u32 = (\\d+);`)) ?? [])[1])
  const tableKey = k('K_TABLE_IDCODE')
  const benchRaw = k('K_BENCH_RAW_IDCODE')
  const row = parsed.fpga.find((r) => r[0] === tableKey)
  if (!row || row[3] !== 'xc7a200') throw new Error(`spec K_TABLE_IDCODE ${hex8(tableKey)} is not the xc7a200 row`)
  if (!benchRec.raw.includes(hex8(benchRaw))) throw new Error(`spec K_BENCH_RAW_IDCODE ${hex8(benchRaw)} is not in the bench record ${benchRec.raw}`)
  if (((benchRaw & 0x0fffffff) >>> 0) !== tableKey) throw new Error('bench raw IDCODE does not mask to the table key')

  const json = {
    source: { repo: `github.com/${REPO}`, tag: TAG, commit: COMMIT, license: 'Apache-2.0', copyright: 'Copyright (C) 2019 Gwenhael Goavec-Merou', files: got, macros: parsed.macros },
    fpga: parsed.fpga.map((r) => [hex8(r[0]), r[1], r[2], r[3], r[4]]),
    shadowed: parsed.shadowed.map((r) => [hex8(r[0]), r[1], r[2], r[3], r[4]]),
    misc: parsed.misc.map((r) => [hex8(r[0]), r[1], r[2]]),
    manufacturers: parsed.manufacturers.map(([c, n]) => ['0x' + c.toString(16).padStart(3, '0'), n]),
    presets,
    bench: benchRec,
  }
  const text = JSON.stringify(json) + '\n'
  writeFileSync(OUT, text)
  console.log(`idcode: wrote ${OUT} (${text.length} bytes): ${json.fpga.length} fpga rows, ${json.shadowed.length} shadowed, ${json.misc.length} misc, ${json.manufacturers.length} manufacturers, ${presets.length} presets; bench ${benchRec.date} raw ${benchRec.raw.join(' ')} printed ${benchRec.printed.join(' ')}`)
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) main()
