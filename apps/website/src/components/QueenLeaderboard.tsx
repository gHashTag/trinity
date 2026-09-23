// LEADERBOARD: who lends the swarm a lane, and what it did there.
//
// Every bee runs on somebody's provider token. The swarm records which lane ran
// each turn, how long it took and what the review said, so this view is a
// reading of work rather than a count of keys lent: a key added and never used
// carries nothing. The scoring comes from the server with the rows
// (`scoring`), so the page states the rule it is drawing rather than a copy of
// it that can drift.
//
// The numbers arrive from /queen/public-leaderboard, which is public on the
// same terms as the board: no issue titles, no worker text, and no credential -
// a lane appears as its index and the name its lender was given.

import { useEffect, useState } from 'react'
import { QUEEN_API } from '../lib/queenApi'
import './QueenLeaderboard.css'

interface Contributor {
  name: string
  claimed: boolean
  /** Their GitHub login, when the operator signed the lane as `@login`. */
  github?: string
  keys: number[]
  accepted: number
  finished: number
  hours: number
  xp: number
}

/**
 * A GitHub login, checked again here rather than trusted from the wire.
 *
 * The server already refuses anything that is not one, and this is the second
 * lock on the same door: the value ends up in an `href` and an `<img src>`, and
 * a page that trusts a remote string to build a profile link is a page that can
 * be pointed at somebody else's account by whoever can write that string.
 */
const GITHUB_LOGIN = /^[a-zA-Z\d](?:[a-zA-Z\d]|-(?=[a-zA-Z\d])){0,38}$/
const loginOf = (row: Contributor) =>
  row.github && GITHUB_LOGIN.test(row.github) ? row.github : null

interface Board {
  days: number
  measuredAt: string
  scoring: { acceptedXp: number; hourXp: number }
  contributors: Contributor[]
}

export interface LeaderboardCopy {
  title: string
  lead: string
  scoring: (accepted: number, hour: number) => string
  rank: string
  who: string
  lanes: string
  accepted: string
  hours: string
  xp: string
  unclaimed: string
  loading: string
  failed: string
  empty: string
  window: (days: number) => string
}

export const LEADERBOARD_COPY: Record<'en' | 'ru', LeaderboardCopy> = {
  en: {
    title: 'LEADERBOARD',
    lead: 'Every bee runs on somebody’s provider token. This is what each lane did.',
    scoring: (accepted, hour) =>
      `${accepted} XP for an issue the Queen accepted on that lane, ${hour} XP for an hour her bees spent on it. Summed from the swarm’s own records on every read.`,
    rank: '#',
    who: 'Lane holder',
    lanes: 'Lanes',
    accepted: 'Accepted',
    hours: 'Bee hours',
    xp: 'XP',
    unclaimed: 'nobody has claimed this lane',
    loading: 'Reading the swarm’s records…',
    failed: 'The leaderboard could not be read.',
    empty: 'No lane has finished a turn in this window.',
    window: (days) => `Last ${days} days`,
  },
  ru: {
    title: 'ЛИДЕРБОРД',
    lead: 'Каждая пчела работает на чьём-то токене провайдера. Вот что сделала каждая полоса.',
    scoring: (accepted, hour) =>
      `${accepted} XP за задачу, которую Королева приняла на этой полосе, и ${hour} XP за час работы пчёл на ней. Складывается из записей самого роя при каждом чтении.`,
    rank: '#',
    who: 'Чья полоса',
    lanes: 'Полосы',
    accepted: 'Принято',
    hours: 'Часы пчёл',
    xp: 'XP',
    unclaimed: 'полосу никто не назвал своей',
    loading: 'Читаю записи роя…',
    failed: 'Лидерборд прочитать не удалось.',
    empty: 'В этом окне ни одна полоса не завершила ход.',
    window: (days) => `За ${days} дней`,
  },
}

const fmt = (n: number) => n.toLocaleString('en-US')

export default function QueenLeaderboard({ lang }: { lang: 'en' | 'ru' }) {
  const c = LEADERBOARD_COPY[lang === 'ru' ? 'ru' : 'en']
  const [board, setBoard] = useState<Board | null | 'failed'>(null)

  useEffect(() => {
    let live = true
    fetch(`${QUEEN_API}/queen/public-leaderboard`, { credentials: 'omit' })
      .then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
      .then((data: Board) => {
        if (live) setBoard(data)
      })
      .catch(() => live && setBoard('failed'))
    return () => {
      live = false
    }
  }, [])

  if (board === null) return <p className="ql-note">{c.loading}</p>
  if (board === 'failed') return <p className="ql-note" role="alert">{c.failed}</p>

  const top = board.contributors[0]?.xp ?? 0

  return (
    <div className="ql">
      <header className="ql-head">
        <h2>{c.title}</h2>
        <p>{c.lead}</p>
        <p className="ql-scoring">{c.scoring(board.scoring.acceptedXp, board.scoring.hourXp)}</p>
        <p className="ql-window">{c.window(board.days)}</p>
      </header>

      {board.contributors.length === 0 ? (
        <p className="ql-note">{c.empty}</p>
      ) : (
        <ol className="ql-rows">
          {board.contributors.map((row, i) => {
            const login = loginOf(row)
            return (
              <li key={row.name} className={`ql-row${row.claimed ? '' : ' is-unclaimed'}`}>
                <span className="ql-rank">{i + 1}</span>
                {/* The avatar comes from github.com/<login>.png, a public
                    redirect: no API call, no token, and a leaderboard that does
                    not wait on GitHub. If it 404s the row still reads. */}
                {login ? (
                  <img
                    className="ql-face"
                    src={`https://github.com/${login}.png?size=96`}
                    alt=""
                    loading="lazy"
                    width={36}
                    height={36}
                  />
                ) : (
                  <span className="ql-face is-anon" aria-hidden="true">
                    ◇
                  </span>
                )}
                <span className="ql-who" title={row.claimed ? undefined : c.unclaimed}>
                  {login ? (
                    <a
                      href={`https://github.com/${login}`}
                      target="_blank"
                      rel="noreferrer noopener"
                    >
                      {row.name}
                    </a>
                  ) : (
                    row.name
                  )}
                  <b className="ql-lanes">
                    {c.lanes}: {row.keys.map((k) => `#${k}`).join(' ')}
                  </b>
                </span>
                {/* The bar is the share of the leader's XP: a rank tells you the
                    order, and this tells you the distance. */}
                <span className="ql-bar" aria-hidden="true">
                  <i style={{ width: `${top > 0 ? Math.max(2, (100 * row.xp) / top) : 0}%` }} />
                </span>
                {/* The three numbers ride in one box so they cannot land on top
                    of each other when the row wraps on a phone. */}
                <span className="ql-nums">
                  <span className="ql-stat">
                    <b>{fmt(row.accepted)}</b> {c.accepted}
                  </span>
                  <span className="ql-stat">
                    <b>{row.hours.toFixed(1)}</b> {c.hours}
                  </span>
                  <span className="ql-xp">
                    {fmt(row.xp)} {c.xp}
                  </span>
                </span>
              </li>
            )
          })}
        </ol>
      )}
    </div>
  )
}
