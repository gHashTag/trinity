// Hardware and silicon history for spec formats that have been through the board.
//
// PROVENANCE — read this before adding a row.
//
// Every figure below is transcribed from
//   research/goldenfloat-hw-conformance/GOLDENFLOAT_HW_CONFORMANCE_v0.2.md
// in gHashTag/trinity-fpga, whose own source is the evidence chain published on
// EPIC #199. A cell is "Tier E" only when all four links exist and are public:
// CI run id -> bitstream SHA-256 -> JTAG flash -> UART log. Tier C (self-report)
// is not represented here at all, because there is none left.
//
// What this data is NOT: it is not a synthesis report for the Verilog that the
// .t27 compiler emits from these specs. That Verilog is a module shell -- across
// the corpus it yields 0 LUTs and 0 flip-flops. The silicon results belong to
// hand-written RTL in external/tt-trinity-corona and fpga/openxc7-synth, verified
// against an oracle written independently of it. The spec and the RTL describe the
// same format; they are not the same artifact, and the UI must say so.

export type OpKind = 'ADD' | 'MUL' | 'SUB' | 'decode'

/** How far a claim has actually been carried. Ordered weakest to strongest. */
export type Level = 'declared' | 'formal' | 'prepared' | 'silicon'

export interface SiliconCell {
  op: OpKind
  level: Level
  /** Exhaustive-or-sampled code coverage, exactly as published, e.g. "512/512". */
  codes?: string
  /** One line on what this particular cell cost or taught. */
  note?: { en: string; ru: string }
}

export interface SiliconRecord {
  /** Catalog format key, e.g. "gf16". */
  format: string
  cells: SiliconCell[]
  /** A defect this format's hardware run exposed that simulation had missed. */
  caseStudy?: { en: string; ru: string }
}

/** The board every one of these numbers was measured on. */
export const DEVICE = {
  board: 'ALINX AX7203',
  part: 'xc7a200tfbg484-2',
  idcode: '0x13636093',
  clock: 'CFGMCLK via STARTUPE2, ~69-70 MHz measured',
  uart: 'CP2102N @ 160000 baud',
} as const

/** The open toolchain. No vendor licence is required at any step. */
export const TOOLCHAIN = {
  synth: 'yosys',
  pnr: 'nextpnr-xilinx',
  db: 'Project X-Ray',
  image: 'regymm/openxc7:latest',
  flash: 'openocd (AL321 / FT2232H)',
  oracle: 'conformance/gf_ref.py — exact rational arithmetic (fractions.Fraction)',
} as const

/** The four links. A cell is Tier E only when it has all of them. */
export const CHAIN: { id: string; en: string; ru: string }[] = [
  { id: 'synth', en: 'openXC7 CI synth', ru: 'синтез в CI (openXC7)' },
  { id: 'bit', en: 'bitstream + SHA-256', ru: 'битстрим + SHA-256' },
  { id: 'flash', en: 'JTAG flash', ru: 'прошивка по JTAG' },
  { id: 'uart', en: 'UART verify vs golden', ru: 'проверка по UART против эталона' },
]

const RECORDS: SiliconRecord[] = [
  {
    format: 'gf4',
    cells: [
      { op: 'ADD', level: 'silicon', codes: '256/256', note: { en: 'BIAS=0 fix', ru: 'исправление BIAS=0' } },
      { op: 'MUL', level: 'silicon', codes: '256/256' },
      { op: 'SUB', level: 'prepared' },
    ],
  },
  {
    format: 'gf8',
    cells: [
      { op: 'ADD', level: 'silicon', codes: '512/512' },
      { op: 'MUL', level: 'silicon', codes: '480/480' },
      { op: 'SUB', level: 'prepared' },
    ],
  },
  {
    format: 'gf12',
    cells: [
      { op: 'ADD', level: 'silicon', codes: '512/512' },
      { op: 'MUL', level: 'silicon', codes: '480/480' },
      { op: 'SUB', level: 'prepared' },
    ],
  },
  {
    format: 'gf16',
    cells: [
      { op: 'ADD', level: 'silicon', codes: '512/512', note: { en: 'NaN fix', ru: 'исправление NaN' } },
      { op: 'MUL', level: 'silicon', codes: '512/512' },
      { op: 'SUB', level: 'prepared' },
    ],
    caseStudy: {
      en: 'GF16 is the only width with HAS_INF=1. The adder returned Inf where NaN was required — and the reference testbench had the same blind spot, so simulation reported 30000/30000 PASS three times running. Only the independently written golden, run against the board, found the 6 failures in 512. Fixed, then 512/512 on silicon.',
      ru: 'GF16 — единственная ширина с HAS_INF=1. Сумматор возвращал Inf там, где требовался NaN, и у эталонного стенда была та же слепая зона: симуляция трижды показала 30000/30000 PASS. Ошибку (6 из 512) нашёл только независимо написанный эталон, запущенный против платы. После исправления — 512/512 на кристалле.',
    },
  },
  {
    format: 'gf20',
    cells: [
      { op: 'ADD', level: 'silicon', codes: '480/480', note: { en: 'placer fix', ru: 'исправление размещения' } },
      { op: 'MUL', level: 'silicon', codes: '480/480' },
      { op: 'SUB', level: 'prepared' },
    ],
    caseStudy: {
      en: 'The GF20 build was cancelled nine times under the wrong diagnosis "Docker Hub pull hang". Per-step CI timing showed the pull took about a minute. The real blocker was place-and-route: the simulated-annealing placer failed to route the wider netlist in 40 minutes; the analytical placer (--placer heap) routed it in about 8 seconds.',
      ru: 'Сборку GF20 отменяли девять раз с неверным диагнозом «зависание docker pull». Потактовый разбор времени в CI показал, что pull занимает около минуты. Настоящей причиной была трассировка: размещение отжигом не развело более широкую схему за 40 минут, аналитический размещатель (--placer heap) справился примерно за 8 секунд.',
    },
  },
  {
    format: 'gf24',
    cells: [
      { op: 'ADD', level: 'silicon', codes: '480/480' },
      { op: 'MUL', level: 'silicon', codes: '480/480', note: { en: 'needs synth_xilinx -nodsp', ru: 'требует synth_xilinx -nodsp' } },
      { op: 'SUB', level: 'prepared' },
    ],
  },
]

export const SILICON: Record<string, SiliconRecord> = Object.fromEntries(
  RECORDS.map((r) => [r.format, r]),
)

/**
 * Spec path -> catalog format. Written out rather than inferred from the filename,
 * so a spec never picks up a hardware claim by resembling one.
 */
export const SPEC_TO_FORMAT: Record<string, string> = {
  'specs/numeric/gf4.t27': 'gf4',
  'specs/numeric/gf8.t27': 'gf8',
  'specs/numeric/gf12.t27': 'gf12',
  'specs/numeric/gf16.t27': 'gf16',
  'specs/numeric/gf20.t27': 'gf20',
  'specs/numeric/gf24.t27': 'gf24',
}

/**
 * Specs that describe the catalog rather than one format. They get the family
 * totals instead of a single format's cells.
 */
export const FAMILY_SPECS = new Set([
  'specs/numeric/goldenfloat_family.t27',
  'specs/numeric/formats.t27',
  'specs/numeric/gf_competitive.t27',
])

/** Catalog-wide totals, as published in the v0.2 draft. */
export const FAMILY_TOTALS = {
  tierE: 27,
  catalog: 83,
  decodeHw: 13,
  addHw: 7,
  mulHw: 7,
  swBitexact: 62,
  structural: 15,
}

/** The formal track: which widths a SAT engine has proven over their whole input space. */
export const FORMAL_PROVEN: Record<string, OpKind[]> = {
  gf4: ['ADD', 'MUL'],
  gf6: ['ADD', 'MUL'],
  gf8: ['ADD'],
  gf12: ['ADD'],
}

export function siliconFor(specPath: string): SiliconRecord | null {
  const key = SPEC_TO_FORMAT[specPath]
  return key ? SILICON[key] ?? null : null
}
