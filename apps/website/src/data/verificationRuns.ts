// Machine verification runs, newest first.
//
// These are runs on MY OWN designs. They are kept separate from client work on
// purpose: a run on your own chip proves the harness works, not that the harness
// is trusted by anyone else. Conflating the two would be the oldest trick on a
// case-studies page.
//
// Every field here comes from the run. The commands are the ones that produced
// the numbers, printed verbatim so a reader can re-run any line. If a check has
// no number, it says so rather than borrowing one from elsewhere.
//
// Toolchain, one machine, 11 August 2026: Yosys 0.65, Icarus Verilog 13.0.

export type Check = {
  name: string
  status: 'PASS' | 'FAIL' | 'SKIP'
  detail: string
  command: string
}

export type Run = {
  id: string
  design: string
  repo: string
  repoUrl: string
  top: string
  tiles: string
  /** What the design is, in one line. */
  what: string
  checks: Check[]
  /** Which checkout the sources came from, for the commit stamp. */
  origin: 't27' | 'trinity-fpga' | 'third-party'
  /** Somebody else's design, not mine. The distinction is the whole point. */
  thirdParty?: boolean
  /** Anything the run surfaced that the author had to act on. */
  found?: string
  date: string
}

/** Stamped on every card. A rounded number reads as a claim; an exact tool
 *  build and a commit SHA read as the output of something that actually ran —
 *  and they answer the question a visitor never asks aloud, which is whether
 *  this thing is still running at all. */
export const PROVENANCE = {
  ranAt: '2026-08-11',
  yosys: 'Yosys 0.65 (git sha1 aec814bdf3071f7e0fd0fbe43f7f711e99d01e24)',
  iverilog: 'Icarus Verilog 13.0 (stable, v13_0)',
  commits: { t27: '592ba4c2d', 'trinity-fpga': 'be4c5d1a' } as Record<string, string>,
}

const LATCH_CMD = 'yosys: select -assert-none t:$_DLATCH_* t:$_DLATCHSR_*' 
const STAT_CMD = 'yosys: read; hierarchy -top; proc; opt; fsm; memory; techmap; flatten; stat'
const FLOP_CMD = 'yosys stat: sum of $_DFF*/$_SDFF*/$_ADFF* cells in the flattened netlist'

export const RUNS: Run[] = [
  {
    id: 'phi',
    origin: 't27',
    design: 'TRI-1 Phi',
    repo: 'gHashTag/t27 · chips/phi',
    repoUrl: 'https://github.com/gHashTag/t27/tree/master/chips/phi',
    top: 'tt_um_trinity_nano',
    tiles: '1x1',
    what: 'Single-tile GF16 ternary dot4 MAC with a Lucas power-on self test.',
    date: '2026-08-11',
    found:
      'The design did not elaborate from the file list info.yaml declares. Three modules — phi_d2d_lite, phi_mesh_bridge, tri_token_accumulator — were present in src/ but absent from source_files, and a Tiny Tapeout shuttle builds from that list. Adding the three files makes it elaborate. Found before the shuttle rather than by it.',
    checks: [
      { name: 'sources resolve', status: 'PASS', detail: '16 of 16 declared files found in src/ (13 before the fix)', command: 'info.yaml source_files -> src/' },
      { name: 'elaborates', status: 'PASS', detail: 'clean, after the three missing files were declared', command: 'iverilog -g2012 -t null -I src -s tt_um_trinity_nano src/*.v' },
      { name: 'no inferred latches', status: 'PASS', detail: 'no $_DLATCH_ cells after techmap', command: LATCH_CMD },
      { name: 'synthesises', status: 'PASS', detail: '10,534 cells including submodules, 4,050 wires. 4,663x $_MUX_, 2,252x $_AND_, 1,660x $_OR_, 1,316x $_XOR_', command: STAT_CMD },
      { name: 'has clocked logic', status: 'PASS', detail: '210 flip-flops, so a clock frequency is a meaningful thing to ask about', command: FLOP_CMD },
    ],
  },
  {
    id: 'euler',
    origin: 't27',
    design: 'TRI-1 Euler',
    repo: 'gHashTag/t27 · chips/euler',
    repoUrl: 'https://github.com/gHashTag/t27/tree/master/chips/euler',
    top: 'tt_um_ghtag_trinity_gf16',
    tiles: '8x2',
    what: 'GF16 e-engine, 8x2 tiles.',
    date: '2026-08-11',
    checks: [
      { name: 'sources resolve', status: 'PASS', detail: '34 of 34 declared files found in src/', command: 'info.yaml source_files -> src/' },
      { name: 'elaborates', status: 'PASS', detail: 'clean from the declared list alone', command: 'iverilog -g2012 -t null -I src -s tt_um_ghtag_trinity_gf16 src/*.v' },
      { name: 'no inferred latches', status: 'PASS', detail: 'no $_DLATCH_ cells after techmap', command: LATCH_CMD },
      { name: 'synthesises', status: 'PASS', detail: '39,991 cells including submodules, 37,170 wires. 18,083x $_MUX_, 8,073x $_AND_, 5,823x $_OR_, 5,469x $_XOR_', command: STAT_CMD },
      { name: 'has clocked logic', status: 'PASS', detail: '473 flip-flops', command: FLOP_CMD },
    ],
  },
  {
    id: 'gamma',
    origin: 't27',
    design: 'TRI-1 Gamma',
    repo: 'gHashTag/t27 · chips/gamma',
    repoUrl: 'https://github.com/gHashTag/t27/tree/master/chips/gamma',
    top: 'tt_um_trinity_max_true',
    tiles: '8x4',
    what: '32-tile, 8-column neuromorphic array.',
    date: '2026-08-11',
    found:
      'Same class of defect as Phi, one file: tri_token_accumulator was in src/ but not in source_files, so the design did not elaborate from what info.yaml declares. Declaring it fixes it.',
    checks: [
      { name: 'sources resolve', status: 'PASS', detail: '44 of 44 declared files found in src/ (43 before the fix)', command: 'info.yaml source_files -> src/' },
      { name: 'elaborates', status: 'PASS', detail: 'clean, after the missing file was declared', command: 'iverilog -g2012 -t null -I src -s tt_um_trinity_max_true src/*.v' },
      { name: 'no inferred latches', status: 'PASS', detail: 'no $_DLATCH_ cells after techmap', command: LATCH_CMD },
      { name: 'synthesises', status: 'PASS', detail: '205,992 cells including submodules, 102,588 wires. 90,628x $_MUX_, 45,141x $_AND_, 32,355x $_OR_, 27,239x $_XOR_', command: STAT_CMD },
      { name: 'has clocked logic', status: 'PASS', detail: '1,929 flip-flops', command: FLOP_CMD },
    ],
  },
  {
    id: 'mini',
    origin: 'trinity-fpga',
    design: 'Quantum Brain MINI',
    repo: 'gHashTag/trinity-fpga · ttsky26c/mini',
    repoUrl: 'https://github.com/gHashTag/trinity-fpga/tree/main/ttsky26c/mini',
    top: 'tt_um_qbrain_mini',
    tiles: '1x1',
    what: 'Single-column cortex: 4 GF16 cells, 75-word ROM, 16-opcode ISA.',
    date: '2026-08-11',
    checks: [
      { name: 'sources resolve', status: 'PASS', detail: 'info.yaml declares no source_files, so src/*.v was globbed: 1 file', command: 'glob src/*.v' },
      { name: 'elaborates', status: 'PASS', detail: 'clean', command: 'iverilog -g2012 -t null -I src -s tt_um_qbrain_mini src/tt_um_qbrain_mini.v' },
      { name: 'no inferred latches', status: 'PASS', detail: 'no $_DLATCH_ cells after techmap', command: LATCH_CMD },
      { name: 'synthesises', status: 'PASS', detail: '49 cells including submodules, 57 wires. 28x $_XOR_, 16x $_DFFE_PN0P_, 1x $_DFF_PN0_', command: STAT_CMD },
      { name: 'has clocked logic', status: 'PASS', detail: '17 flip-flops', command: FLOP_CMD },
    ],
  },
  {
    id: 'holo',
    origin: 'trinity-fpga',
    design: 'Quantum Brain HOLOGRAPHIC',
    repo: 'gHashTag/trinity-fpga · ttsky26c/holo',
    repoUrl: 'https://github.com/gHashTag/trinity-fpga/tree/main/ttsky26c/holo',
    top: 'tt_um_qbrain_holo',
    tiles: '1x2',
    what: 'Holographic variant of the Quantum Brain column.',
    date: '2026-08-11',
    checks: [
      { name: 'sources resolve', status: 'PASS', detail: 'info.yaml declares no source_files, so src/*.v was globbed: 1 file', command: 'glob src/*.v' },
      { name: 'elaborates', status: 'PASS', detail: 'clean', command: 'iverilog -g2012 -t null -I src -s tt_um_qbrain_holo src/tt_um_qbrain_holo.v' },
      { name: 'no inferred latches', status: 'PASS', detail: 'no $_DLATCH_ cells after techmap', command: LATCH_CMD },
      { name: 'synthesises', status: 'PASS', detail: '128 cells including submodules, 193 wires. 63x $_DFFE_PN0P_, 42x $_XOR_, 3x $_DFF_PN0_', command: STAT_CMD },
      { name: 'has clocked logic', status: 'PASS', detail: '66 flip-flops', command: FLOP_CMD },
    ],
  },
]

/** What the automated run does NOT establish. Stated on the page, not buried. */
export const LIMITS_EN = [
  'A pass is not a proof of correctness. These five checks say the design elaborates, infers no latches, synthesises, and contains clocked logic. None of them compares the design against a specification.',
  'Generic yosys cells are not silicon area. Phi and MINI are both 1x1 tiles and differ by three orders of magnitude in cell count; only the real ASIC flow settles whether either fits.',
  'No frequency is claimed. Counting flip-flops says a frequency is a meaningful question, not what the answer is. That needs place-and-route on a named part.',
  'Nothing here ran on hardware. These are simulation and synthesis results on one machine.',
]

export const LIMITS_RU = [
  'Пройденная проверка — не доказательство корректности. Эти пять проверок говорят, что дизайн элаборируется, не выводит защёлок, синтезируется и содержит тактируемую логику. Ни одна из них не сверяет дизайн со спецификацией.',
  'Родовые ячейки yosys — не площадь на кремнии. Phi и MINI оба 1×1, а различаются по числу ячеек на три порядка; влезает ли каждый из них, решает только настоящий ASIC-поток.',
  'Частота не заявляется. Счёт триггеров говорит, что вопрос о частоте осмыслен, а не каков ответ. Для ответа нужна разводка на конкретном кристалле.',
  'Ничего из этого не выполнялось на железе. Это результаты симуляции и синтеза на одной машине.',
]

/** Designs by other people, checked with the same harness on the same day.
 *
 * These matter more than the five above, and the reason is uncomfortable: two of
 * my own chips did not elaborate from the file list their own info.yaml declared,
 * and all three of these did. A gallery that only ever flatters its author is a
 * showroom. The instrument is only credible because it was pointed the other way
 * first and something was found.
 *
 * All three are public Tiny Tapeout submissions under an open licence. Nothing
 * here is a judgement about the designs — these are structural facts anyone can
 * reproduce with the commands printed on each card.
 */
export const THIRD_PARTY_RUNS: Run[] = [
  {
    id: 'tinygpu',
    design: 'TinyGPU v2',
    repo: 'pongsagon/tt_um_pongsagon_tinygpu_v2',
    repoUrl: 'https://github.com/pongsagon/tt_um_pongsagon_tinygpu_v2',
    top: 'tt_um_pongsagon_tinygpu_v2',
    tiles: 'see info.yaml',
    what: "Somebody else's GPU, the largest of the three.",
    date: '2026-08-11',
    origin: 'third-party',
    thirdParty: true,
    checks: [
      { name: 'sources resolve', status: 'PASS', detail: '10 of 10 declared files found', command: 'info.yaml source_files -> src/' },
      { name: 'elaborates', status: 'PASS', detail: 'clean from the declared list alone', command: 'iverilog -g2012 -t null -I src -s <top> <declared sources>' },
      { name: 'no inferred latches', status: 'PASS', detail: 'no $_DLATCH_ cells after techmap', command: LATCH_CMD },
      { name: 'synthesises', status: 'PASS', detail: '34,223 cells including submodules, 15,846 wires. 11,251x $_AND_, 9,213x $_OR_, 5,942x $_MUX_, 3,065x $_XOR_', command: STAT_CMD },
      { name: 'has clocked logic', status: 'PASS', detail: '3,383 flip-flops', command: FLOP_CMD },
    ],
  },
  {
    id: 'float-synth',
    design: 'Float synth',
    repo: 'NikLeberg/tt_um_float_synth',
    repoUrl: 'https://github.com/NikLeberg/tt_um_float_synth',
    top: 'tt_um_float_synth_nikleberg',
    tiles: 'see info.yaml',
    what: 'A floating-point synthesiser — the closest of the three to my own subject.',
    date: '2026-08-11',
    origin: 'third-party',
    thirdParty: true,
    checks: [
      { name: 'sources resolve', status: 'PASS', detail: '2 of 2 declared files found', command: 'info.yaml source_files -> src/' },
      { name: 'elaborates', status: 'PASS', detail: 'clean from the declared list alone', command: 'iverilog -g2012 -t null -I src -s <top> <declared sources>' },
      { name: 'no inferred latches', status: 'PASS', detail: 'no $_DLATCH_ cells after techmap', command: LATCH_CMD },
      { name: 'synthesises', status: 'PASS', detail: '900 cells including submodules, 904 wires. 210x $_NOT_, 197x $_OR_, 180x $_AND_, 180x $_DFF_P_', command: STAT_CMD },
      { name: 'has clocked logic', status: 'PASS', detail: '183 flip-flops', command: FLOP_CMD },
    ],
  },
  {
    id: 'serv-soc',
    design: 'SERV RISC-V SoC on Wishbone',
    repo: 'divadnauj-GB/tt_um_divadnauj-GB_serv_soc_wb',
    repoUrl: 'https://github.com/divadnauj-GB/tt_um_divadnauj-GB_serv_soc_wb',
    top: 'tt_um_divadnauj_GB_serv_soc_wb',
    tiles: 'see info.yaml',
    what: 'A bit-serial RISC-V core with a Wishbone SoC around it, across 40 declared files.',
    date: '2026-08-11',
    origin: 'third-party',
    thirdParty: true,
    checks: [
      { name: 'sources resolve', status: 'PASS', detail: '40 of 40 declared files found', command: 'info.yaml source_files -> src/' },
      { name: 'elaborates', status: 'PASS', detail: 'clean from the declared list alone', command: 'iverilog -g2012 -t null -I src -s <top> <declared sources>' },
      { name: 'no inferred latches', status: 'PASS', detail: 'no $_DLATCH_ cells after techmap', command: LATCH_CMD },
      { name: 'synthesises', status: 'PASS', detail: '8,301 cells including submodules, 4,903 wires. 2,081x $_AND_, 1,957x $_OR_, 1,605x $_MUX_, 689x $_DFFE_PP0P_', command: STAT_CMD },
      { name: 'has clocked logic', status: 'PASS', detail: '1,751 flip-flops', command: FLOP_CMD },
    ],
  },
]
