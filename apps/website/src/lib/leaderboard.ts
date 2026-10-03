// The LEADERBOARD's lanes: the shape `/queen/public-leaderboard` publishes, the
// rule for whose GitHub account a lane is, and the one read of it.
//
// The LEADERBOARD tab draws these rows and the TOKEN tab pays them (owner,
// 2026-10-03: the tokens are counted by the leaderboard), so both take the row,
// the login and the read from here. Two copies of "whose lane is this" would
// let the board and the pay disagree about the same person.
//
// Imports only import-free files: plain node runs it in the qa contracts.

import { githubLogin } from './githubLogin.ts'

export interface Contributor {
  name: string
  claimed: boolean
  /** Their GitHub login, when the operator signed the lane as `@login`. */
  github?: string
  /** The lanes ran on the lender's own machine: a runner, named by Telegram. */
  runner?: boolean
  keys: number[]
  accepted: number
  /** Accepted issues whose boundary named a .t27 file: the game's own goal. */
  specs?: number
  finished: number
  hours: number
  xp: number
}

export interface Leaderboard {
  /** The window in days, or null for the whole record. */
  days: number | null
  measuredAt: string
  scoring: { acceptedXp: number; specXp?: number; hourXp: number }
  contributors: Contributor[]
}

/**
 * Whose GitHub account a lane is. The server already refuses anything that is
 * not a login; this is the second lock on the same door.
 */
export const laneLogin = (row: Pick<Contributor, 'github'>): string | null => githubLogin(row.github)

/** `base` is QUEEN_API; passed in so this file stays free of Vite's env. */
export async function readLeaderboard(base: string, signal?: AbortSignal): Promise<Leaderboard> {
  const r = await fetch(`${base}/queen/public-leaderboard`, { credentials: 'omit', signal })
  if (!r.ok) throw new Error(`public-leaderboard ${r.status}`)
  return (await r.json()) as Leaderboard
}
