// WHO CONTRIBUTED: the merge rule, kept apart from the component that draws it.
//
// GitHub answers per repository, so the same person arrives once per repository
// they touched and has to be summed. That is the whole of this file, and it is
// here rather than inside the view so it can be driven directly by a test
// without a browser, a fetch or a render.
//
// It is deliberately suspicious of what comes back. The avatar URL is BUILT
// from the login rather than taken from the payload: a URL from a remote body
// is a URL somebody else chose for this page to load. A row without a login, or
// with a count that is not a positive number, is dropped rather than shown as
// zero - a name on this board should mean somebody committed something.

/** The public repositories. A private one is left out: it 404s anonymously. */
export const PEOPLE_REPOS = [
  'gHashTag/t27',
  'gHashTag/trinity',
  'gHashTag/BrowserOS',
  'gHashTag/trios',
] as const

export interface Person {
  login: string
  avatar: string
  commits: number
  repos: string[]
  /** An account whose name ends in [bot]: shown, and marked, never hidden. */
  bot: boolean
}

export interface ContributorRow {
  login?: unknown
  contributions?: unknown
}

/** Merge one repository's contributors into the running tally. */
export function absorb(
  into: Map<string, Person>,
  repo: string,
  rows: ContributorRow[],
): void {
  for (const row of rows) {
    if (typeof row.login !== 'string' || !row.login) continue
    const commits = Number(row.contributions)
    if (!Number.isFinite(commits) || commits <= 0) continue
    const seen = into.get(row.login)
    if (seen) {
      seen.commits += commits
      if (!seen.repos.includes(repo)) seen.repos.push(repo)
      continue
    }
    into.set(row.login, {
      login: row.login,
      avatar: `https://github.com/${row.login}.png?size=96`,
      commits,
      repos: [repo],
      bot: row.login.endsWith('[bot]'),
    })
  }
}

/** Most commits first; ties by login, so two readings never swap places. */
export function rankPeople(tally: Map<string, Person>): Person[] {
  return [...tally.values()].sort(
    (a, b) => b.commits - a.commits || a.login.localeCompare(b.login),
  )
}
