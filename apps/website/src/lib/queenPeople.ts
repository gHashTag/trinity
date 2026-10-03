// WHO WROTE THE SPECS: the shape of the published answer, and nothing else.
//
// The first version of this board counted commits in the repositories, which
// answered a question nobody asked. BrowserOS is a fork, so its top contributor
// by that measure had 1,335 commits and has never touched a `.t27` file - a
// board about a project rewriting itself into one language listed, second,
// somebody with no connection to it. Owner's word, 2026-09-23: only the people
// who made the specs belong here.
//
// The counting moved to `scripts/spec-authors.mjs`, which finds every public
// repository with `.t27` files, walks the commits under them with a token,
// credits each to a GitHub account, and publishes
// `public/roadmap/spec-authors.json`. The page reads that file: an honest
// answer needs dozens of GitHub pages and anonymous GitHub allows sixty
// requests an hour, so a live read could only ever have been a partial one.

import { githubLogin } from './githubLogin.ts'

/** How a commit reached its account; see `attribute` in the script. */
export type CreditedVia = 'author' | 'pr' | 'committer' | 'name'

/** One row: a GitHub account. Since 2026-10-02 nothing else is ever a row. */
export interface SpecAuthor {
  login: string
  avatar: string | null
  commits: number
  /** How many of `commits` came by each route, so the page can say so. */
  via: Partial<Record<CreditedVia, number>>
  repos: string[]
}

/** Commits no GitHub account answers for: a number, never a person. */
export interface Unattributed {
  commits: number
  /** The names on those commits, for the reader who wants to know whose. */
  names: Record<string, number>
}

export interface SpecAuthors {
  measuredAt: string
  /** What was counted, in the file's own words, so the page states it. */
  method: string
  sources: Array<{ repo: string; path: string }>
  /** Repositories or paths whose history was longer than the script would walk. */
  truncated: string[]
  unattributed: Unattributed
  people: SpecAuthor[]
}

/** A GitHub login, checked rather than trusted: it becomes an `href`. */
export function loginOf(person: Pick<SpecAuthor, 'login'>): string | null {
  return githubLogin(person.login)
}

/** The published answer. Relative, so it works under app.t27.ai/queen/ too. */
export async function readSpecAuthors(signal?: AbortSignal): Promise<SpecAuthors> {
  const r = await fetch('roadmap/spec-authors.json', { credentials: 'omit', signal })
  if (!r.ok) throw new Error(`spec-authors.json ${r.status}`)
  return (await r.json()) as SpecAuthors
}

/** The repositories the counted specs live in, each once, in file order. */
export function sourceRepos(data: SpecAuthors): string[] {
  return [...new Set(data.sources.map((s) => s.repo.replace(/^gHashTag\//, '')))]
}
