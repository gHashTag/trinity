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
// So the count is now commits touching each repository's spec directory,
// computed by `scripts/spec-authors.mjs` and published as
// `roadmap/spec-authors.json`. The page states what was counted by reading the
// file's own `method` rather than restating it, so the two cannot drift.
//
// AUTOMATION IS SHOWN, NOT HIDDEN. The swarm commits as itself and its work on
// the corpus is real; a board that dropped it would overstate how much of the
// language was written by hand. An author GitHub could not resolve to an
// account gets no link and no face, and the row says which.

import { useEffect, useState } from 'react'
import {
  loginOf,
  nameOf,
  type SpecAuthor,
  type SpecAuthors,
} from '../lib/queenPeople'
import './QueenPeople.css'

export interface PeopleCopy {
  title: string
  lead: string
  commits: string
  repos: string
  unlinked: string
  loading: string
  failed: string
  measured: string
}

export const PEOPLE_COPY: Record<'en' | 'ru', PeopleCopy> = {
  en: {
    title: 'WHO WROTE THE SPECS',
    lead: 'Everyone whose commits reached the .t27 corpus. Not everyone with commits in these repositories \u2014 the specs are what this project is.',
    commits: 'spec commits',
    repos: 'repositories',
    unlinked: 'no GitHub account on these commits',
    loading: 'Reading the count\u2026',
    failed: 'The count could not be read.',
    measured: 'Measured',
  },
  ru: {
    title: '\u041a\u0422\u041e \u041f\u0418\u0421\u0410\u041b \u0421\u041f\u0415\u041a\u0418',
    lead: '\u0412\u0441\u0435, \u0447\u044c\u0438 \u043a\u043e\u043c\u043c\u0438\u0442\u044b \u0434\u043e\u0448\u043b\u0438 \u0434\u043e \u043a\u043e\u0440\u043f\u0443\u0441\u0430 .t27. \u041d\u0435 \u0432\u0441\u0435, \u0443 \u043a\u043e\u0433\u043e \u0435\u0441\u0442\u044c \u043a\u043e\u043c\u043c\u0438\u0442\u044b \u0432 \u044d\u0442\u0438\u0445 \u0440\u0435\u043f\u043e\u0437\u0438\u0442\u043e\u0440\u0438\u044f\u0445 \u2014 \u043f\u0440\u043e\u0435\u043a\u0442 \u0435\u0441\u0442\u044c \u0441\u043f\u0435\u043a\u0438.',
    commits: '\u043a\u043e\u043c\u043c\u0438\u0442\u043e\u0432 \u0432 \u0441\u043f\u0435\u043a\u0438',
    repos: '\u0440\u0435\u043f\u043e\u0437\u0438\u0442\u043e\u0440\u0438\u0435\u0432',
    unlinked: '\u043d\u0430 \u044d\u0442\u0438\u0445 \u043a\u043e\u043c\u043c\u0438\u0442\u0430\u0445 \u043d\u0435\u0442 \u0430\u043a\u043a\u0430\u0443\u043d\u0442\u0430 GitHub',
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
          const name = nameOf(person)
          return (
            <li key={name} className={`qp-row${login ? '' : ' is-unlinked'}`}>
              <span className="qp-rank">{i + 1}</span>
              {login ? (
                <img
                  className="qp-face"
                  src={`https://github.com/${login}.png?size=96`}
                  alt=""
                  loading="lazy"
                  width={36}
                  height={36}
                />
              ) : (
                <span className="qp-face is-anon" aria-hidden="true">
                  ◇
                </span>
              )}
              <span className="qp-who" title={login ? undefined : c.unlinked}>
                {login ? (
                  <a
                    href={`https://github.com/${login}`}
                    target="_blank"
                    rel="noreferrer noopener"
                  >
                    {name}
                  </a>
                ) : (
                  name
                )}
                <b className="qp-repos">
                  {person.repos.length} {c.repos}: {person.repos.join(', ')}
                </b>
              </span>
              <span className="qp-commits">
                <b>{fmt(person.commits)}</b> {c.commits}
              </span>
            </li>
          )
        })}
      </ol>
      {/* The method comes from the file rather than being restated here, so
          what the page claims and what the script counted cannot drift. */}
      <p className="qp-counted">
        {c.measured}: {data.measuredAt.slice(0, 10)} · {data.method}
      </p>
    </section>
  )
}
