// WHO EARNED TRI: the leaderboard's own counts, at the ledger's rate.
//
// Owner, 2026-10-03: "tokens are counted by the leaderboard; the logic there is
// right". The TOKEN tab used to rank a third source, the Queen's earnings
// ledger, which knew one lane lender and 377 acceptances, while the leaderboard
// the same visitor opens one tab away showed four spec authors and 595 accepted
// .t27 specs. Two boards about one reward that disagree are one board too many.
//
// So this file adds nothing to what the leaderboard knows. The rows, the
// logins and the reads are the leaderboard's own (lib/queenPeople.ts,
// lib/leaderboard.ts, lib/githubLogin.ts); the only thing here is the sum:
//
//   TRI = (spec commits by the account + accepted .t27 specs on its lanes)
//         x triPerSpec, the rate the ledger states (owner's choice,
//         2026-10-03: specs x 27)
//
// One row per GitHub account, both roads summed; what no account answers for
// is a number under the list, never a row.
//
// Imports only import-free files: plain node runs it in qa/tri-board-contract.mjs.

import { laneLogin, type Contributor } from './leaderboard.ts'
import { loginOf, type SpecAuthor } from './queenPeople.ts'

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

const count = (n: unknown) => (typeof n === 'number' && Number.isFinite(n) && n > 0 ? Math.floor(n) : 0)

/** A rate is a whole, positive number of TRI, or there is no rate. */
export const validRate = (rate: unknown): rate is number =>
  typeof rate === 'number' && Number.isInteger(rate) && rate > 0

export function triBoard(
  authors: Pick<SpecAuthor, 'login' | 'commits'>[],
  lanes: Pick<Contributor, 'github' | 'specs'>[],
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
    const who = loginOf(a)
    if (who) row(who).specCommits += count(a.commits)
    else nobody.specCommits += count(a.commits)
  }
  for (const l of lanes) {
    const who = laneLogin(l)
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
