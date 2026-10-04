// The rules of LEVEL II, as pure functions, so a contract can hold them.
//
// Everything here is computed from public facts - GitHub's issue search, the
// Queen's public board and the roadmap's goals.json - and nothing is stored.
// The page's own score (honey) and its own rules (the raid, when a boss fight
// opens) are named as the board's, never as the Queen's XP, which only the
// Queen's leaderboard reports.

export interface RuleGoal {
  stage: number
  locked?: { en: string; ru: string }
}

export interface RuleTask {
  stage: number | null
  units: number
  state: string
  /** ISO time the issue was closed, for built cells. */
  closedAt?: string | null
}

const DAY_MS = 86_400_000

/** Whole UTC days since the epoch: the raid changes at UTC midnight. */
export function utcDay(nowMs: number): number {
  return Math.floor(nowMs / DAY_MS)
}

/** Milliseconds until the next UTC midnight, when the raid moves. */
export function msToNextDay(nowMs: number): number {
  return DAY_MS - (nowMs % DAY_MS)
}

/**
 * The stages a raid can fall on: stages 1-7 with nothing locking them.
 * With today's goals.json that is [1, 2, 5, 6, 7], and gHashTag/t27
 * tools/queen/feed_roadmap.py holds the same list as RAID_STAGES, so the
 * feeder and this page name the same sector on the same UTC day. Unlocking a
 * stage in goals.json means changing that list too.
 */
export function raidStages(goals: RuleGoal[]): number[] {
  return goals
    .filter((g) => g.stage >= 1 && g.stage <= 7 && !g.locked)
    .map((g) => g.stage)
    .sort((a, b) => a - b)
}

/** Today's raid sector: the eligible stages in turn, one per UTC day. */
export function raidOf(goals: RuleGoal[], day: number): number | null {
  const stages = raidStages(goals)
  return stages.length ? stages[((day % stages.length) + stages.length) % stages.length] : null
}

/**
 * Honey: the functions ported in built cells. A cell of the raid sector that
 * was closed today counts double. This is the board's own score.
 */
export function honeyOf(tasks: RuleTask[], raid: number | null, day: number): number {
  let honey = 0
  for (const t of tasks) {
    if (t.state !== 'built' && t.state !== 'cracked') continue
    const today = t.closedAt ? utcDay(Date.parse(t.closedAt)) === day : false
    honey += t.units * (raid !== null && t.stage === raid && today ? 2 : 1)
  }
  return honey
}

/** The share of the comb below the bosses (stages 1-7) that is built, 0..1. */
export function builtShareBelow(tasks: RuleTask[]): number {
  const below = tasks.filter((t) => t.stage !== null && t.stage <= 7)
  if (below.length === 0) return 0
  return below.filter((t) => t.state === 'built' || t.state === 'cracked').length / below.length
}

/** A boss fight opens when this share of the comb below it is built. */
export const BOSS_OPENS_AT = 0.5

/** The `.t27` a port task creates, read from its title: `... to specs/port/<x>.t27`. */
export function targetOf(title: string): string | null {
  const m = /\bto (specs\/port\/\S+?\.t27)\b/.exec(title)
  return m ? m[1] : null
}

/**
 * Built files with an open defect against them. A title that names a
 * `specs/port/...t27` and is not itself a port task is a report that the
 * file, once built, is wrong now - the queen-doctor and the feeders file them
 * that way. Each such file is a cracked cell until its defect closes.
 */
export function crackedTargets(openTitles: string[]): Set<string> {
  const out = new Set<string>()
  for (const title of openTitles) {
    if (/^Port /.test(title)) continue
    for (const m of title.matchAll(/specs\/port\/[\w./-]+?\.t27/g)) out.add(m[0])
  }
  return out
}

/**
 * Where the Queen's round is, 0 at its start and 1 at its end, from the
 * board's own pulse. Null when the board gave no usable pulse.
 */
export function pulsePhase(lastRoundAt: string | null, roundSeconds: number, nowMs: number): number | null {
  if (!lastRoundAt || !(roundSeconds > 0)) return null
  const at = Date.parse(lastRoundAt)
  if (!Number.isFinite(at)) return null
  const elapsed = Math.max(0, (nowMs - at) / 1000)
  return (elapsed % roundSeconds) / roundSeconds
}

export const EXT_LANG: Record<string, string> = {
  py: 'Python', sh: 'Shell', ts: 'TypeScript', mts: 'TypeScript', js: 'JavaScript', mjs: 'JavaScript',
  go: 'Go', rs: 'Rust', zig: 'Zig', c: 'C', v: 'Verilog', sv: 'Verilog', gleam: 'Gleam',
}

/** `Port [part N of M of ][owner/repo:]path (Lang, N functions) to ...` */
export function parsePortTitle(title: string): { repo: string; path: string; lang: string; units: number } | null {
  const m = /^Port (?:part \d+ of \d+ of )?(?:([\w.-]+\/[\w.-]+):)?(\S+)(?: \(([\w+#]+), (\d+) (?:functions?|modules?)\))?/.exec(title)
  if (!m) return null
  const path = m[2]
  const ext = path.includes('.') ? path.slice(path.lastIndexOf('.') + 1) : ''
  return {
    repo: m[1] ?? 'gHashTag/t27',
    path,
    lang: m[3] ?? EXT_LANG[ext] ?? '',
    // A title that does not say is read as middling, not as quick.
    units: m[4] ? Number(m[4]) : 4,
  }
}

/** Rows of an apex-down pyramid, bottom (the point) first: row r holds r + 1 cells. */
export function rowsFor(cells: number): number {
  let rows = 1
  while ((rows * (rows + 1)) / 2 < cells) rows += 1
  return Math.min(Math.max(rows, 9), 16)
}

