// LEADERBOARD: who builds t27, and the runners lent to the swarm.
//
// The tab used to rank provider lanes as well: "#-2 #0 #1 … #10009" under one
// holder, then "◇key #24", with XP per lane. The owner struck it out of the top
// (2026-10-03): a lane is plumbing, not a person, and a list of key indices told
// a visitor nothing about who did the work. The lanes are still counted -- the
// specs a lane carried reach its owner's TRI on the TOKEN tab through
// readTriCounts -- they are just not a ranking of their own here.

import QueenPeople from './QueenPeople'
import QueenRunners from './QueenRunners'
import './QueenLeaderboard.css'

export interface LeaderboardCopy {
  title: string
  howTo: string
}

export const LEADERBOARD_COPY: Record<'en' | 'ru', LeaderboardCopy> = {
  en: {
    title: 'LEADERBOARD',
    howTo: 'How to lend the swarm a provider token — and which providers forbid it',
  },
  ru: {
    title: 'ЛИДЕРБОРД',
    howTo: 'Как одолжить рою свой токен провайдера — и кто из провайдеров это запрещает',
  },
}

export default function QueenLeaderboard({ lang }: { lang: 'en' | 'ru' }) {
  const l = lang === 'ru' ? 'ru' : 'en'
  const c = LEADERBOARD_COPY[l]

  return (
    <div className="ql">
      <header className="ql-head">
        <h2>{c.title}</h2>
        {/* The tutorial is where the how lives, including the part that costs
            us the simple version of the pitch: what each provider's terms
            actually say. */}
        <a className="ql-howto" href="https://t27.ai/blog/how-to-join-the-swarm/" target="_blank" rel="noreferrer noopener">
          {c.howTo} →
        </a>
      </header>

      {/* PEOPLE: GitHub's own record of who wrote the specs. */}
      <QueenPeople lang={l} />

      {/* Lend a lane by running it yourself, with your key on your machine. */}
      <QueenRunners lang={l} />
    </div>
  )
}
