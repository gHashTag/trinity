// SPEC EARNINGS: which accepted .t27 commits the swarm wrote down as earned.
//
// The numbers arrive from /queen/public-earnings: one earning per (repository,
// issue, judged commit) the Queen accepted when the turn declared a .t27 file,
// and the ones a later verdict on the same commit took back. Public on the same
// terms as the leaderboard - no titles, no worker text, no notes.
//
// The server says in its own answer that nothing here is withdrawable and that
// TRI per spec is undecided, and this panel prints that sentence - translated
// only when it is word for word the one it knows, and sent through unchanged
// otherwise: a count beside a token's name reads as money, and the one place
// allowed to say otherwise is the record itself.

import { useEffect, useState } from 'react'
import { QUEEN_API } from '../lib/queenApi'
import { githubLogin } from '../lib/githubLogin'
import './QueenSpecEarnings.css'

interface Earner {
  name: string
  claimed: boolean
  github?: string
  keys: number[]
  earned: number
  revoked: number
}

interface Ledger {
  status: string
  triPerSpec: number | null
  rules: { counts: string; revokes: string; notYet: string[] }
  totals: { earned: number; revoked: number }
  earners: Earner[]
}

interface SpecEarningsCopy {
  title: string
  lead: string
  earned: string
  revoked: string
  notYet: string
  absent: string
  empty: string
  /** The server's status sentence in this language, used only when the server
   *  says exactly NOT_WITHDRAWABLE; any other status is printed as sent. */
  notWithdrawable: string
}

const NOT_WITHDRAWABLE = 'recorded, not withdrawable: no token is deployed'

const SPEC_EARNINGS_COPY: Record<'en' | 'ru', SpecEarningsCopy> = {
  en: {
    title: 'SPEC EARNINGS',
    lead: 'Each accepted .t27 commit is written down once, with an id anyone can recompute from the repository, issue and commit. A later send-back of the same commit takes it back, and the record keeps both.',
    earned: 'earned',
    revoked: 'taken back',
    notYet: 'Not yet true',
    absent: 'The earnings record is not published by the swarm yet.',
    empty: 'No accepted .t27 commit has been recorded yet.',
    notWithdrawable: 'Recorded, not withdrawable: no token is deployed.',
  },
  ru: {
    title: 'ЗАРАБОТОК ЗА СПЕКИ',
    lead: 'Каждый принятый коммит со спекой .t27 записывается один раз, с идентификатором, который любой пересчитает из репозитория, задачи и коммита. Если тот же коммит позже вернули на доработку, запись отзывается, и в журнале остаются обе.',
    earned: 'заработано',
    revoked: 'отозвано',
    notYet: 'Пока не так',
    absent: 'Рой ещё не публикует журнал заработка.',
    empty: 'Ни одного принятого коммита со спекой .t27 ещё не записано.',
    notWithdrawable: 'Записано, вывести нельзя: токен не выпущен.',
  },
}

export default function QueenSpecEarnings({ lang }: { lang: 'en' | 'ru' }) {
  const c = SPEC_EARNINGS_COPY[lang]
  const [ledger, setLedger] = useState<Ledger | null | 'absent'>(null)

  useEffect(() => {
    let live = true
    fetch(`${QUEEN_API}/queen/public-earnings`, { credentials: 'omit' })
      .then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
      .then((data: Ledger) => {
        if (live) setLedger(data)
      })
      // Absent, not failed: until the swarm serving this page has the route,
      // the honest reading is that the record is not published, and saying the
      // leaderboard broke would send its reader looking for a fault.
      .catch(() => live && setLedger('absent'))
    return () => {
      live = false
    }
  }, [])

  if (ledger === null) return null

  return (
    <section className="ql-earnings">
      <h3 className="ql-lanes-title">{c.title}</h3>
      <p className="ql-lanes-lead">{c.lead}</p>
      {ledger === 'absent' ? (
        <p className="ql-note">{c.absent}</p>
      ) : (
        <>
          {/* The sentence that keeps a count from reading as a balance. */}
          <p className="ql-scoring">{ledger.status === NOT_WITHDRAWABLE ? c.notWithdrawable : ledger.status}</p>
          {ledger.earners.length === 0 ? (
            <p className="ql-note">{c.empty}</p>
          ) : (
            <ol className="ql-rows">
              {ledger.earners.map((row, i) => {
                const login = githubLogin(row.github)
                return (
                  <li key={row.name} className={`ql-row${row.claimed ? '' : ' is-unclaimed'}`}>
                    <span className="ql-rank">{i + 1}</span>
                    <span className="ql-who">
                      {login ? (
                        <a href={`https://github.com/${login}`} target="_blank" rel="noreferrer noopener">
                          {row.name}
                        </a>
                      ) : (
                        row.name
                      )}
                    </span>
                    <span className="ql-nums">
                      <span className="ql-stat is-spec">
                        <b>{row.earned}</b> {c.earned}
                      </span>
                      <span className="ql-stat">
                        <b>{row.revoked}</b> {c.revoked}
                      </span>
                    </span>
                  </li>
                )
              })}
            </ol>
          )}
          <p className="ql-window">{c.notYet}:</p>
          <ul className="ql-lanes-lead">
            {ledger.rules.notYet.map((line) => (
              <li key={line}>{line}</li>
            ))}
          </ul>
        </>
      )}
    </section>
  )
}
