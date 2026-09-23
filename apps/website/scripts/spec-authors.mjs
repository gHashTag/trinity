// WHO WROTE THE SPECS — the only contribution this project is actually about.
//
//   GH_TOKEN=$(gh auth token) node scripts/spec-authors.mjs > public/roadmap/spec-authors.json
//
// WHY THIS REPLACED A COMMIT COUNT. The PEOPLE board first read GitHub's
// `/contributors` endpoint, which answers "who has commits in this repository"
// - and BrowserOS is a fork, so its top contributor by that measure had 1,335
// commits and has never touched a `.t27` file. A board about a project that is
// rewriting itself into one language listed, second, somebody with no
// connection to it. Owner's word, 2026-09-23: only the people who made the
// specs belong here.
//
// WHAT IS COUNTED, EXACTLY: commits that touch a directory where this project's
// `.t27` specs live, per repository, by author. Not every file under those
// directories is a spec, and a commit is not a file - so this is a measure of
// work ON the corpus, and the JSON says so in its own `method` field rather
// than leaving a reader to assume something finer.
//
// WHY A FILE AND NOT A LIVE READ: the page used to ask GitHub on every visit,
// and anonymous GitHub allows sixty requests an hour per address while an
// honest answer needs dozens of pages. A generated file costs the visitor
// nothing, cannot be rate-limited, and is regenerated the same way
// `roadmap-stack.mjs` regenerates the stack count.
//
// It never clones anything: a first version of the stack count did, and filled
// the disk of the machine it was measuring from.

const TOKEN = process.env.GH_TOKEN ?? process.env.GITHUB_TOKEN
if (!TOKEN) {
  console.error('spec-authors: set GH_TOKEN, e.g. GH_TOKEN=$(gh auth token)')
  process.exit(1)
}

/**
 * Where each repository keeps the specs. A repository whose specs move is one
 * line here; a repository with none is simply absent, which is why `trios` is
 * not listed - it has no commits under a spec directory of its own.
 */
const SOURCES = [
  { repo: 'gHashTag/t27', path: 'specs' },
  { repo: 'gHashTag/trinity', path: 'apps/website/specs' },
  { repo: 'gHashTag/BrowserOS', path: 'trios' },
  { repo: 'gHashTag/turbobaby-user-bot', path: 'specs' },
]

/** Pages of 100. The cap is a bound on cost, and the JSON records if it bit. */
const MAX_PAGES = 40

async function gh(url) {
  const res = await fetch(`https://api.github.com/${url}`, {
    headers: {
      authorization: `Bearer ${TOKEN}`,
      accept: 'application/vnd.github+json',
      'user-agent': 'trinity-spec-authors',
    },
  })
  if (!res.ok) throw new Error(`${url}: ${res.status} ${await res.text()}`)
  return res.json()
}

/**
 * COMMIT ADDRESSES THAT ARE AN AGENT, NOT A PERSON WITH AN ACCOUNT.
 *
 * Claude Code commits as `Claude <claude@anthropic.com>` by default. GitHub
 * resolves that address to github.com/claude - an account registered by an
 * unrelated person in 2009 - so the board drew a stranger's avatar, linked
 * their profile, and credited them with 67 spec commits made on the owner's
 * machine under the owner's direction.
 *
 * That is not a display preference to argue about: linking one person's work
 * to another person's profile is wrong whichever way the credit is meant to
 * fall. These addresses are named here, shown as the agent they are, and never
 * linked.
 *
 * The real repair is upstream - a git author address belonging to whoever runs
 * the agent - and until that happens this keeps the board from asserting
 * something false about a bystander.
 */
const AGENT_EMAILS = new Map([
  ['claude@anthropic.com', 'Claude Code (agent)'],
  ['noreply@anthropic.com', 'Claude Code (agent)'],
])

const people = new Map()

/** One author, keyed by login where GitHub knows one, else by the name on the commit. */
function credit(key, { login, avatar, name }, repo) {
  const seen = people.get(key)
  if (seen) {
    seen.commits += 1
    if (!seen.repos.includes(repo)) seen.repos.push(repo)
    return
  }
  people.set(key, {
    login,
    name,
    // Built from the login where there is one; an account GitHub does not know
    // gets no avatar rather than a guessed URL.
    avatar: login ? `https://github.com/${login}.png?size=96` : null,
    commits: 1,
    repos: [repo],
    bot: Boolean(login?.endsWith('[bot]')),
  })
}

const truncated = []
for (const { repo, path } of SOURCES) {
  const short = repo.replace('gHashTag/', '')
  let page = 1
  for (; page <= MAX_PAGES; page += 1) {
    const rows = await gh(
      `repos/${repo}/commits?path=${encodeURIComponent(path)}&per_page=100&page=${page}`,
    )
    if (!Array.isArray(rows) || rows.length === 0) break
    for (const row of rows) {
      const email = (row.commit?.author?.email ?? '').toLowerCase()
      const agent = AGENT_EMAILS.get(email)
      if (agent) {
        // Keyed by the agent name, never by the account GitHub guessed from
        // the address: that account belongs to somebody else.
        credit(`agent:${agent}`, { login: null, avatar: null, name: agent }, short)
        continue
      }
      const login = row.author?.login ?? null
      const name = row.commit?.author?.name ?? login
      if (!login && !name) continue
      credit(login ?? `name:${name}`, { login, avatar: null, name }, short)
    }
    if (rows.length < 100) break
  }
  if (page > MAX_PAGES) truncated.push(repo)
}

// A COMMIT WITHOUT A LINKED ACCOUNT IS THE SAME PERSON UNDER ANOTHER NAME.
//
// GitHub resolves `author.login` only when the commit's email belongs to an
// account. The same person committing from an unlinked address arrives as a
// bare name, and the first run of this script listed gHashTag twice: 994 with
// the login and 2 without. Fold a name into a login when they match, so one
// person is one row.
for (const [key, row] of [...people]) {
  if (!key.startsWith('name:')) continue // `agent:` rows are never folded
  const match = [...people.values()].find(
    (other) => other.login && other.login.toLowerCase() === (row.name ?? '').toLowerCase(),
  )
  if (!match) continue
  match.commits += row.commits
  for (const repo of row.repos) if (!match.repos.includes(repo)) match.repos.push(repo)
  people.delete(key)
}

// An entry GitHub cannot resolve to an account is not a person this board can
// link to, and most of them are the swarm committing as itself. Say which
// rather than dropping them: the bees' work on the corpus is real, and a board
// that hid it would overstate how much of the language was written by hand.
for (const row of people.values()) row.linked = Boolean(row.login)

const ranked = [...people.values()].sort(
  (a, b) => b.commits - a.commits || (a.login ?? a.name).localeCompare(b.login ?? b.name),
)

process.stdout.write(
  `${JSON.stringify(
    {
      measuredAt: new Date().toISOString(),
      method:
        'Commits touching a directory where this project keeps its .t27 specs, per repository, by author. A measure of work on the spec corpus: not every file under those directories is a spec, and a commit is not a file.',
      sources: SOURCES.map((s) => ({ ...s, repo: s.repo })),
      truncated,
      people: ranked,
    },
    null,
    2,
  )}\n`,
)
