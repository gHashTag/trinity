// WHO WROTE THE SPECS: the shape of the published answer, and nothing else.
//
// The first version of this board counted commits in the repositories, which
// answered a question nobody asked. BrowserOS is a fork, so its top contributor
// by that measure had 1,335 commits and has never touched a `.t27` file - a
// board about a project rewriting itself into one language listed, second,
// somebody with no connection to it. Owner's word, 2026-09-23: only the people
// who made the specs belong here.
//
// The counting moved to `scripts/spec-authors.mjs`, which walks commits under
// each repository's spec directory with a token and publishes
// `public/roadmap/spec-authors.json`. The page reads that file: an honest
// answer needs dozens of GitHub pages and anonymous GitHub allows sixty
// requests an hour, so a live read could only ever have been a partial one.

export interface SpecAuthor {
  /** The GitHub login, when the commit's email belongs to an account. */
  login: string | null
  /** The name on the commit, which is all there is when it does not. */
  name: string | null
  avatar: string | null
  commits: number
  repos: string[]
  bot: boolean
  /** Whether GitHub resolved this author to an account at all. */
  linked: boolean
}

export interface SpecAuthors {
  measuredAt: string
  /** What was counted, in the file's own words, so the page states it. */
  method: string
  sources: Array<{ repo: string; path: string }>
  /** Repositories whose history was longer than the script would walk. */
  truncated: string[]
  people: SpecAuthor[]
}

/**
 * A GitHub login, checked here rather than trusted from the file, because it
 * becomes an `href` and an `<img src>`. The file is ours, but the rule that a
 * page never builds a link to a person out of an unchecked string does not
 * become less true when the string is one we wrote.
 */
const GITHUB_LOGIN = /^[a-zA-Z\d](?:[a-zA-Z\d]|-(?=[a-zA-Z\d])){0,38}$/

export function loginOf(person: SpecAuthor): string | null {
  return person.linked && person.login && GITHUB_LOGIN.test(person.login)
    ? person.login
    : null
}

/** What to call somebody: their login, else the name on their commits. */
export function nameOf(person: SpecAuthor): string {
  return person.login ?? person.name ?? 'unknown'
}
