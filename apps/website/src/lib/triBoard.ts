// WHO EARNED TRI: the leaderboard's own counts, at the ledger's rate.
//
// Owner, 2026-10-03: "tokens are counted by the leaderboard; the logic there is
// right". The TOKEN tab used to rank a third source, the Queen's earnings
// ledger, which knew one lane lender and 377 acceptances, while the leaderboard
// the same visitor opens one tab away showed four spec authors and 595 accepted
// .t27 specs. Two boards about one reward that disagree are one board too many.
//
// So this file reads what the leaderboard reads, and nothing else:
//
// - WHO WROTE THE SPECS (`roadmap/spec-authors.json`): commits to the .t27
//   corpus per GitHub account -- the spec author's road;
// - LANES (`/queen/public-leaderboard`): accepted issues whose boundary named a
//   .t27 file, per lender -- the proof-of-compute road;
//
// and pays each unit at `triPerSpec`, the rate the ledger states (owner's
// choice, 2026-10-03: specs x 27). One row per GitHub account, both roads
// summed; what no account answers for is a number under the list, never a row.
//
// No imports on purpose: plain node runs it in qa/tri-board-contract.mjs.

/** One author row of `roadmap/spec-authors.json`. */
export interface AuthorUnits {
  login: string
  commits: number
}

/** One lane row of `/queen/public-leaderboard`. */
export interface LaneUnits {
  name: string
  claimed: boolean
  github?: string
  keys: number[]
  /** Accepted issues whose boundary named a .t27 file. */
  specs?: number
}

export interface TriRow {
  login: string
  specCommits: number
  laneSpecs: number
  /** null when no rate could be read: the units stand, the TRI is not guessed. */
  tri: number | null
}

export interface TriBoard {
  rows: TriRow[]
  /** Units no GitHub account answers for. */
  nobody: { specCommits: number; laneSpecs: number; tri: number | null }
  /** Everything earned, credited or not. */
  total: number | null
}

const GITHUB_LOGIN = /^[a-zA-Z\d](?:[a-zA-Z\d]|-(?=[a-zA-Z\d])){0,38}$/
const login = (s: string | undefined) => (s && GITHUB_LOGIN.test(s) ? s : null)
const count = (n: unknown) => (typeof n === 'number' && Number.isFinite(n) && n > 0 ? Math.floor(n) : 0)

/** A rate is a whole, positive number of TRI, or there is no rate. */
export const validRate = (rate: unknown): rate is number =>
  typeof rate === 'number' && Number.isInteger(rate) && rate > 0

export function triBoard(
  authors: AuthorUnits[],
  lanes: LaneUnits[],
  triPerSpec: number | null | undefined,
  unattributedCommits = 0,
): TriBoard {
  const rate = validRate(triPerSpec) ? triPerSpec : null
  const pay = (units: number) => (rate === null ? null : units * rate)
  const byLogin = new Map<string, { login: string; specCommits: number; laneSpecs: number }>()
  const nobody = { specCommits: count(unattributedCommits), laneSpecs: 0 }

  const row = (name: string) => {
    const key = name.toLowerCase()
    const r = byLogin.get(key) ?? { login: name, specCommits: 0, laneSpecs: 0 }
    byLogin.set(key, r)
    return r
  }

  for (const a of authors) {
    const who = login(a.login)
    if (who) row(who).specCommits += count(a.commits)
    else nobody.specCommits += count(a.commits)
  }
  for (const l of lanes) {
    const who = l.claimed ? login(l.github) : null
    if (who) row(who).laneSpecs += count(l.specs)
    else nobody.laneSpecs += count(l.specs)
  }

  const rows = [...byLogin.values()]
    .filter((r) => r.specCommits + r.laneSpecs > 0)
    .map((r) => ({ ...r, tri: pay(r.specCommits + r.laneSpecs) }))
    .sort(
      (a, b) =>
        b.specCommits + b.laneSpecs - (a.specCommits + a.laneSpecs) || a.login.localeCompare(b.login),
    )
  const units = rows.reduce((s, r) => s + r.specCommits + r.laneSpecs, 0) + nobody.specCommits + nobody.laneSpecs
  return {
    rows,
    nobody: { ...nobody, tri: pay(nobody.specCommits + nobody.laneSpecs) },
    total: pay(units),
  }
}
