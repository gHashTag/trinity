// WHO ACTUALLY CONTRIBUTED, WITH THEIR NAMES AND THEIR FACES.
//
// The lane board answers "whose provider key did a bee run on", which is a real
// question but not the one a visitor asks first. The first question is who
// worked on this - and the answer was `key #0`, because a lane is only given a
// name when the operator writes one into TRIOS_KEY_OWNERS. Until they do, the
// board that was supposed to show people showed slot numbers.
//
// This half needs no configuration at all and never did. Four of the five
// repositories are public, and GitHub's own contributors endpoint gives the
// login, the avatar and the commit count for each person, anonymously. So the
// people who built this can be named today rather than after a variable is set.
//
// WHAT IS COUNTED: commits on the default branch of each public repository, as
// GitHub counts them, summed per person across the repositories. That is a
// measure of volume and nothing else - it does not know a one-line fix from a
// subsystem, and this page says so rather than implying a ranking of worth.
//
// BOTS ARE SHOWN, NOT HIDDEN. An account ending in [bot] is marked as
// automation instead of being dropped: the swarm's own commits are a real part
// of this history, and a board that quietly removed them would be a board that
// overstates how much of this was typed by hand.

import { useEffect, useState } from 'react'
import { absorb, type ContributorRow, PEOPLE_REPOS, type Person, rankPeople } from '../lib/queenPeople'
import './QueenPeople.css'

export interface PeopleCopy {
  title: string
  lead: string
  commits: string
  repos: string
  bot: string
  loading: string
  failed: string
  counted: string
}

export const PEOPLE_COPY: Record<'en' | 'ru', PeopleCopy> = {
  en: {
    title: 'PEOPLE',
    lead: 'Everyone with commits in the open repositories of this project, read live from GitHub.',
    commits: 'commits',
    repos: 'repositories',
    bot: 'automation',
    loading: 'Asking GitHub who worked here\u2026',
    failed: 'GitHub did not answer, so this half is unknown rather than guessed.',
    counted:
      'Commits on each default branch, summed across the four open repositories. A measure of volume, not of worth: it cannot tell a one-line fix from a subsystem.',
  },
  ru: {
    title: '\u041b\u042e\u0414\u0418',
    lead: '\u0412\u0441\u0435, \u0443 \u043a\u043e\u0433\u043e \u0435\u0441\u0442\u044c \u043a\u043e\u043c\u043c\u0438\u0442\u044b \u0432 \u043e\u0442\u043a\u0440\u044b\u0442\u044b\u0445 \u0440\u0435\u043f\u043e\u0437\u0438\u0442\u043e\u0440\u0438\u044f\u0445 \u043f\u0440\u043e\u0435\u043a\u0442\u0430, \u043f\u0440\u043e\u0447\u0438\u0442\u0430\u043d\u043e \u0441 GitHub \u0432\u0436\u0438\u0432\u0443\u044e.',
    commits: '\u043a\u043e\u043c\u043c\u0438\u0442\u043e\u0432',
    repos: '\u0440\u0435\u043f\u043e\u0437\u0438\u0442\u043e\u0440\u0438\u0435\u0432',
    bot: '\u0430\u0432\u0442\u043e\u043c\u0430\u0442\u0438\u043a\u0430',
    loading: '\u0421\u043f\u0440\u0430\u0448\u0438\u0432\u0430\u044e \u0443 GitHub, \u043a\u0442\u043e \u0437\u0434\u0435\u0441\u044c \u0440\u0430\u0431\u043e\u0442\u0430\u043b\u2026',
    failed: 'GitHub \u043d\u0435 \u043e\u0442\u0432\u0435\u0442\u0438\u043b, \u043f\u043e\u044d\u0442\u043e\u043c\u0443 \u044d\u0442\u0430 \u043f\u043e\u043b\u043e\u0432\u0438\u043d\u0430 \u043d\u0435\u0438\u0437\u0432\u0435\u0441\u0442\u043d\u0430, \u0430 \u043d\u0435 \u0432\u044b\u0434\u0443\u043c\u0430\u043d\u0430.',
    counted:
      '\u041a\u043e\u043c\u043c\u0438\u0442\u044b \u0432 \u043e\u0441\u043d\u043e\u0432\u043d\u043e\u0439 \u0432\u0435\u0442\u043a\u0435 \u043a\u0430\u0436\u0434\u043e\u0433\u043e \u0438\u0437 \u0447\u0435\u0442\u044b\u0440\u0451\u0445 \u043e\u0442\u043a\u0440\u044b\u0442\u044b\u0445 \u0440\u0435\u043f\u043e\u0437\u0438\u0442\u043e\u0440\u0438\u0435\u0432, \u043f\u0440\u043e\u0441\u0443\u043c\u043c\u0438\u0440\u043e\u0432\u0430\u043d\u043d\u044b\u0435. \u042d\u0442\u043e \u043c\u0435\u0440\u0430 \u043e\u0431\u044a\u0451\u043c\u0430, \u0430 \u043d\u0435 \u0446\u0435\u043d\u043d\u043e\u0441\u0442\u0438: \u043e\u043d\u0430 \u043d\u0435 \u043e\u0442\u043b\u0438\u0447\u0438\u0442 \u043f\u0440\u0430\u0432\u043a\u0443 \u0432 \u043e\u0434\u043d\u0443 \u0441\u0442\u0440\u043e\u043a\u0443 \u043e\u0442 \u043f\u043e\u0434\u0441\u0438\u0441\u0442\u0435\u043c\u044b.',
  },
}

/** Fifteen minutes, per tab. Anonymous GitHub allows 60 requests an hour. */
const CACHE_KEY = 'trinity.people.v1'
const CACHE_MS = 15 * 60 * 1000

function cached(): Person[] | null {
  try {
    const raw = sessionStorage.getItem(CACHE_KEY)
    if (!raw) return null
    const { at, people } = JSON.parse(raw) as { at: number; people: Person[] }
    return Date.now() - at < CACHE_MS ? people : null
  } catch {
    return null
  }
}

function remember(people: Person[]): void {
  try {
    sessionStorage.setItem(CACHE_KEY, JSON.stringify({ at: Date.now(), people }))
  } catch {
    /* a private window has no storage, and the board works without it */
  }
}

const fmt = (n: number) => n.toLocaleString('en-US')

export default function QueenPeople({ lang }: { lang: 'en' | 'ru' }) {
  const c = PEOPLE_COPY[lang === 'ru' ? 'ru' : 'en']
  const [people, setPeople] = useState<Person[] | null | 'failed'>(() => cached())

  useEffect(() => {
    if (people !== null) return
    let live = true
    Promise.all(
      PEOPLE_REPOS.map((repo) =>
        fetch(`https://api.github.com/repos/${repo}/contributors?per_page=100`, {
          credentials: 'omit',
        })
          .then((r) => (r.ok ? r.json() : []))
          .then((rows: ContributorRow[]) => [repo, Array.isArray(rows) ? rows : []] as const)
          .catch(() => [repo, [] as ContributorRow[]] as const),
      ),
    )
      .then((answers) => {
        if (!live) return
        const tally = new Map<string, Person>()
        for (const [repo, rows] of answers) absorb(tally, repo.replace('gHashTag/', ''), rows)
        const ranked = rankPeople(tally)
        // Every repository refusing is indistinguishable from nobody having
        // ever committed, and the second is a lie. Say unknown instead.
        if (ranked.length === 0) {
          setPeople('failed')
          return
        }
        setPeople(ranked)
        remember(ranked)
      })
      .catch(() => live && setPeople('failed'))
    return () => {
      live = false
    }
  }, [people])

  if (people === null) return <p className="qp-note">{c.loading}</p>
  if (people === 'failed')
    return (
      <p className="qp-note" role="alert">
        {c.failed}
      </p>
    )

  return (
    <section className="qp" aria-label={c.title}>
      <h3 className="qp-title">{c.title}</h3>
      <p className="qp-lead">{c.lead}</p>
      <ol className="qp-rows">
        {people.map((p, i) => (
          <li key={p.login} className={`qp-row${p.bot ? ' is-bot' : ''}`}>
            <span className="qp-rank">{i + 1}</span>
            <img className="qp-face" src={p.avatar} alt="" loading="lazy" width={36} height={36} />
            <span className="qp-who">
              <a href={`https://github.com/${p.login}`} target="_blank" rel="noreferrer noopener">
                {p.login}
              </a>
              <b className="qp-repos">
                {p.bot ? `${c.bot} · ` : ''}
                {p.repos.length} {c.repos}: {p.repos.join(', ')}
              </b>
            </span>
            <span className="qp-commits">
              <b>{fmt(p.commits)}</b> {c.commits}
            </span>
          </li>
        ))}
      </ol>
      <p className="qp-counted">{c.counted}</p>
    </section>
  )
}
