// WHO WROTE THE SPECS, WITH THEIR NAMES AND THEIR FACES.
//
// The lane board answers "whose provider key did a bee run on". This one
// answers the question a visitor asks first: who built this?
//
// It used to answer it wrongly. Reading GitHub's `/contributors` endpoint
// counts anyone with commits in the repository, and BrowserOS is a fork - so
// the second name on the board had 1,335 commits and has never touched a
// `.t27` file. Owner's word, 2026-09-23: only the people who made the specs
// belong here, because the specs are what this project is.
//
// So the count is now commits touching every public directory that holds
// `.t27` files, computed by `scripts/spec-authors.mjs` and published as
// `roadmap/spec-authors.json`. The page states what was counted by reading the
// file's own `method` rather than restating it, so the two cannot drift.
//
// EVERY ROW IS A GITHUB ACCOUNT. Owner's word, 2026-10-02: "Claude Code
// (agent)" is not a GitHub account; rank by GitHub names. The swarm's and the
// agents' commits are credited to whoever opened the merged pull request that
// carried them, and the row says how many came that way. What no account
// answers for is one number under the list, never a row of its own.

import { useEffect, useState } from 'react'
import {
  loginOf,
  sourceRepos,
  type SpecAuthor,
  type SpecAuthors,
} from '../lib/queenPeople'
import './QueenPeople.css'

export interface PeopleCopy {
  title: string
  lead: string
  commits: string
  repos: string
  viaPr: string
  unattributed: string
  countedIn: string
  loading: string
  failed: string
  measured: string
}

export const PEOPLE_COPY: Record<'en' | 'ru', PeopleCopy> = {
  en: {
    title: 'WHO WROTE THE SPECS',
    lead: 'Every GitHub account whose commits reached the .t27 corpus. Not everyone with commits in these repositories \u2014 the specs are what this project is.',
    commits: 'spec commits',
    repos: 'repositories',
    viaPr: 'through their merged pull requests',
    unattributed: 'spec commits have no GitHub account behind them and no merged pull request, so they are counted here and credited to nobody',
    countedIn: 'Counted in',
    loading: 'Reading the count\u2026',
    failed: 'The count could not be read.',
    measured: 'Measured',
  },
  ru: {
    title: '\u041a\u0422\u041e \u041f\u0418\u0421\u0410\u041b \u0421\u041f\u0415\u041a\u0418',
    lead: '\u041a\u0430\u0436\u0434\u044b\u0439 \u0430\u043a\u043a\u0430\u0443\u043d\u0442 GitHub, \u0447\u044c\u0438 \u043a\u043e\u043c\u043c\u0438\u0442\u044b \u0434\u043e\u0448\u043b\u0438 \u0434\u043e \u043a\u043e\u0440\u043f\u0443\u0441\u0430 .t27. \u041d\u0435 \u0432\u0441\u0435, \u0443 \u043a\u043e\u0433\u043e \u0435\u0441\u0442\u044c \u043a\u043e\u043c\u043c\u0438\u0442\u044b \u0432 \u044d\u0442\u0438\u0445 \u0440\u0435\u043f\u043e\u0437\u0438\u0442\u043e\u0440\u0438\u044f\u0445 \u2014 \u043f\u0440\u043e\u0435\u043a\u0442 \u0435\u0441\u0442\u044c \u0441\u043f\u0435\u043a\u0438.',
    commits: '\u043a\u043e\u043c\u043c\u0438\u0442\u043e\u0432 \u0432 \u0441\u043f\u0435\u043a\u0438',
    repos: '\u0440\u0435\u043f\u043e\u0437\u0438\u0442\u043e\u0440\u0438\u0438',
    viaPr: '\u0447\u0435\u0440\u0435\u0437 \u0441\u0432\u043e\u0438 \u0441\u043c\u0435\u0440\u0436\u0435\u043d\u043d\u044b\u0435 \u043f\u0443\u043b\u043b-\u0440\u0435\u043a\u0432\u0435\u0441\u0442\u044b',
    unattributed: '\u043a\u043e\u043c\u043c\u0438\u0442\u043e\u0432 \u0432 \u0441\u043f\u0435\u043a\u0438 \u043d\u0435 \u0441\u0432\u044f\u0437\u0430\u043d\u044b \u043d\u0438 \u0441 \u043e\u0434\u043d\u0438\u043c \u0430\u043a\u043a\u0430\u0443\u043d\u0442\u043e\u043c GitHub \u0438 \u043d\u0438 \u0441 \u043e\u0434\u043d\u0438\u043c \u0441\u043c\u0435\u0440\u0436\u0435\u043d\u043d\u044b\u043c \u043f\u0443\u043b\u043b-\u0440\u0435\u043a\u0432\u0435\u0441\u0442\u043e\u043c, \u043f\u043e\u044d\u0442\u043e\u043c\u0443 \u043e\u043d\u0438 \u043f\u043e\u0441\u0447\u0438\u0442\u0430\u043d\u044b \u0437\u0434\u0435\u0441\u044c \u0438 \u043d\u0435 \u043f\u0440\u0438\u043f\u0438\u0441\u0430\u043d\u044b \u043d\u0438\u043a\u043e\u043c\u0443',
    countedIn: '\u041f\u043e\u0441\u0447\u0438\u0442\u0430\u043d\u043e \u0432',
    loading: '\u0427\u0438\u0442\u0430\u044e \u043f\u043e\u0434\u0441\u0447\u0451\u0442\u2026',
    failed: '\u041f\u043e\u0434\u0441\u0447\u0451\u0442 \u043f\u0440\u043e\u0447\u0438\u0442\u0430\u0442\u044c \u043d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c.',
    measured: '\u0418\u0437\u043c\u0435\u0440\u0435\u043d\u043e',
  },
}

const fmt = (n: number) => n.toLocaleString('en-US')

export default function QueenPeople({ lang }: { lang: 'en' | 'ru' }) {
  const c = PEOPLE_COPY[lang === 'ru' ? 'ru' : 'en']
  const [data, setData] = useState<SpecAuthors | null | 'failed'>(null)

  useEffect(() => {
    let live = true
    // Relative, so the view works under app.t27.ai/queen/ as well as t27.ai.
    fetch('roadmap/spec-authors.json', { credentials: 'omit' })
      .then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
      .then((rows: SpecAuthors) => live && setData(rows))
      .catch(() => live && setData('failed'))
    return () => {
      live = false
    }
  }, [])

  if (data === null) return <p className="qp-note">{c.loading}</p>
  if (data === 'failed')
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
        {data.people.map((person: SpecAuthor, i: number) => {
          const login = loginOf(person)
          if (!login) return null
          const viaPr = person.via.pr ?? 0
          return (
            <li key={login} className="qp-row">
              <span className="qp-rank">{i + 1}</span>
              <img
                className="qp-face"
                src={`https://github.com/${login}.png?size=96`}
                alt=""
                loading="lazy"
                width={36}
                height={36}
              />
              <span className="qp-who">
                <a
                  href={`https://github.com/${login}`}
                  target="_blank"
                  rel="noreferrer noopener"
                >
                  {login}
                </a>
                <b className="qp-repos">
                  {c.repos}: {person.repos.join(', ')}
                </b>
              </span>
              <span className="qp-commits">
                <b>{fmt(person.commits)}</b> {c.commits}
                {viaPr > 0 && (
                  <small className="qp-via">
                    {fmt(viaPr)} {c.viaPr}
                  </small>
                )}
              </span>
            </li>
          )
        })}
      </ol>
      {data.unattributed?.commits > 0 && (
        <p
          className="qp-counted"
          title={Object.entries(data.unattributed.names)
            .map(([name, n]) => `${name}: ${n}`)
            .join(', ')}
        >
          <b>{fmt(data.unattributed.commits)}</b> {c.unattributed}.
        </p>
      )}
      <p className="qp-counted">
        {c.countedIn}: {sourceRepos(data).join(', ')}
      </p>
      {/* The method comes from the file rather than being restated here, so
          what the page claims and what the script counted cannot drift. */}
      <p className="qp-counted">
        {c.measured}: {data.measuredAt.slice(0, 10)} · {data.method}
      </p>
    </section>
  )
}
