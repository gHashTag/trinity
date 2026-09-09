import { useI18n } from '../i18n/context'
import { TrinityLogo } from './TrinityLogo'
import './GameHero.css'

// The front door.
//
// The mark first — it is the thing people recognise — and then, in one line,
// what this site is now: a game whose board is the corpus of .t27 specs. The
// number the game exists to build (r² = r + 1, the format claim and the evidence
// under it) has its own page, linked from here and from the nav, so that a
// reader who came for the arithmetic reaches all of it in one place instead of
// scrolling past it to find the board.
const COPY = {
  en: {
    wordmark: 'TERNARY NETWORK FLOATS',
    title: 'The core is a game, and the board is public',
    lede: 'Every cell on the map is a .t27 spec or the GitHub issue that pays for it. Take one, write the spec that generates it, compile it with the real compiler, send it. That is the whole contribution process, and it is the whole game.',
    play: 'How to play',
    map: 'Open the map',
    number: 'The number behind it →',
  },
  ru: {
    wordmark: 'ТЕРНАРНЫЕ СЕТЕВЫЕ ЧИСЛА',
    title: 'Ядро — это игра, и доска открыта',
    lede: 'Каждая сота на карте — спека .t27 или задача GitHub, которая за неё платит. Возьмите одну, напишите спеку, которая её порождает, скомпилируйте настоящим компилятором, отправьте. Это весь процесс контрибуции — и вся игра.',
    play: 'Как играть',
    map: 'Открыть карту',
    number: 'Число за этим →',
  },
} as const

export default function GameHero() {
  const { lang } = useI18n()
  const t = COPY[lang === 'ru' ? 'ru' : 'en']

  return (
    <section className="game-hero" id="hero" aria-labelledby="game-hero-title">
      <div className="game-hero-inner">
        <TrinityLogo withLabel={false} height="clamp(104px, 16vw, 190px)" />
        <span className="game-hero-wordmark">{t.wordmark}</span>
        <h1 id="game-hero-title">{t.title}</h1>
        <p>{t.lede}</p>
        <div className="game-hero-actions">
          <a className="game-hero-primary" href="#/queen">
            {t.map}
          </a>
          <a className="game-hero-secondary" href="#play">
            {t.play}
          </a>
          <a className="game-hero-quiet" href="#/trinity">
            {t.number}
          </a>
        </div>
      </div>
    </section>
  )
}
