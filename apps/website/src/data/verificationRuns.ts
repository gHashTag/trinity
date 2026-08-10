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
  what: string
  checks: Check[]
  found?: string
  date: string
  origin: string
  thirdParty?: boolean
  /** A caveat the card must show, e.g. that the design is a declared skeleton. */
  note?: string
  /** Path under /r/. Identifies the design, not the repository. */
  slug: string
}

// runs.json is the single source of truth. The static generator in the publish
// repo reads the same file to emit the per-repo result pages and the badge
// endpoints, so a run cannot say one thing here and another there — which it
// could when the data lived only in this module and the generator carried its
// own prose copy of it.
import data from './runs.json'

export const PROVENANCE = data.provenance as {
  ranAt: string
  yosys: string
  iverilog: string
  commits: Record<string, string>
}

const ALL = data.runs as Run[]

export const RUNS: Run[] = ALL.filter((r) => !r.thirdParty)
export const THIRD_PARTY_RUNS: Run[] = ALL.filter((r) => r.thirdParty)

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
