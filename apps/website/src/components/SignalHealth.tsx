"use client";
import { useI18n } from '../i18n/context'
import data from '../data/signalHealth.json'

// My own instruments, measured by the check I sell.
//
// The service rests on the claim that a check is worth having only if somebody
// reads it — T12: at P(red) = 1 the next red carries −log₂(1) = 0 bits. It would
// be indefensible to publish that and keep my own number in a terminal, and the
// number is bad: the repository this whole service is built in has a CI job that
// has failed on every run in the window.
//
// It goes on the page for the same reason the failed adjudications do. A
// verification service that shows only its good measurements is advertising.

type Entry = {
  repo: string
  workflow: string
  note: string
  window?: number
  failures?: number
  streak?: number
  streakIsLowerBound?: boolean
  bitsPerRed?: number | null
  lastGreen?: string | null
  error?: string
}

const ENTRIES = (data.entries ?? []) as Entry[]

const T = {
  en: {
    h2: 'My own instruments, measured by the check I sell',
    lede:
      'T12 below says a build red on every run carries zero bits: the next red cannot distinguish the world before it from the world after. Publishing that while keeping my own number in a terminal would not survive a single question, so here it is.',
    bad:
      'The repository this service is built in has a CI job that has failed on every run in the window — the streak is longer than the window can see, and its last green was in March. That is worse than the six-week red on my chip that the theorem was written about, by two orders of magnitude. It is being repaired: the first cause is a refactor that moved sources out from under the build without moving the references, and six of the fourteen dangling paths are already fixed.',
    good:
      'The checks this service actually offers are separate workflows with their own verdicts, and they are green. That is not an excuse — it is the reason the damage is bounded, and it is only true because they were never folded into the same job.',
    cols: ['Instrument', 'Window', 'Failed', 'Streak', 'Bits per red', 'Last green'],
    never: 'none in window',
    zero: '0 — carries nothing',
  },
  ru: {
    h2: 'Мои собственные приборы, измеренные той проверкой, которую я продаю',
    lede:
      'T12 ниже говорит: сборка, красная в каждом прогоне, несёт ноль бит — очередное красное не отличает мир до себя от мира после. Публиковать это и держать свою цифру в терминале не выдержало бы и одного вопроса, поэтому вот она.',
    bad:
      'В репозитории, где построен этот сервис, есть CI-задание, упавшее в каждом прогоне окна — серия длиннее, чем окно способно увидеть, а последний зелёный был в марте. Это хуже той шестинедельной красноты на моём чипе, о которой написана теорема, на два порядка. Чинится: первопричина — рефакторинг, вынесший исходники из-под сборки без переноса ссылок, и шесть из четырнадцати висячих путей уже исправлены.',
    good:
      'Проверки, которые сервис действительно предлагает, — отдельные воркфлоу со своими вердиктами, и они зелёные. Это не оправдание: именно поэтому ущерб ограничен, и так вышло только потому, что их никогда не сливали в одно задание.',
    cols: ['Прибор', 'Окно', 'Падений', 'Серия', 'Бит на красное', 'Последний зелёный'],
    never: 'нет в окне',
    zero: '0 — не несёт ничего',
  },
}

export default function SignalHealth() {
  const { lang } = useI18n()
  const t = lang === 'ru' ? T.ru : T.en
  const loc = lang === 'ru' ? 'ru-RU' : 'en-US'

  return (
    <div className="premium-card" style={{ textAlign: 'left', marginBottom: '2rem' }}>
      <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginTop: 0, marginBottom: '0.6rem' }}>{t.h2}</h2>
      <p style={{ fontSize: '0.95rem', lineHeight: 1.65, opacity: 0.88, maxWidth: '68ch', margin: '0 0 1.3rem' }}>{t.lede}</p>

      <div style={{ overflowX: 'auto', marginBottom: '1.3rem' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '0.84rem', minWidth: '640px' }}>
          <thead>
            <tr style={{ borderBottom: '1px solid var(--border)' }}>
              {t.cols.map((c, i) => (
                <th key={c} style={{ textAlign: i === 0 || i === 5 ? 'left' : 'right', padding: '0.5rem 0.6rem', opacity: 0.7, fontWeight: 600 }}>{c}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {ENTRIES.map((e) => {
              const dead = (e.streak ?? 0) > 0 && e.bitsPerRed === null
              return (
                <tr key={e.repo + e.workflow} style={{ borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
                  <td style={{ padding: '0.5rem 0.6rem' }}>
                    <span style={{ fontFamily: 'monospace', fontSize: '0.8rem' }}>{e.workflow}</span>
                    <span style={{ display: 'block', opacity: 0.6, fontSize: '0.76rem' }}>{e.note}</span>
                  </td>
                  <td style={{ padding: '0.5rem 0.6rem', textAlign: 'right', fontVariantNumeric: 'tabular-nums' }}>{e.window ?? '—'}</td>
                  <td style={{ padding: '0.5rem 0.6rem', textAlign: 'right', fontVariantNumeric: 'tabular-nums' }}>{e.failures ?? '—'}</td>
                  <td style={{ padding: '0.5rem 0.6rem', textAlign: 'right', fontVariantNumeric: 'tabular-nums', color: dead ? '#ff8a6b' : 'inherit', fontWeight: dead ? 700 : 400 }}>
                    {e.streakIsLowerBound ? '≥ ' : ''}{e.streak ?? '—'}
                  </td>
                  <td style={{ padding: '0.5rem 0.6rem', textAlign: 'right', color: dead ? '#ff8a6b' : 'var(--accent)' }}>
                    {e.bitsPerRed === null || e.bitsPerRed === undefined
                      ? ((e.failures ?? 0) === 0 ? '—' : t.zero)
                      : e.bitsPerRed.toFixed(2)}
                  </td>
                  <td style={{ padding: '0.5rem 0.6rem', opacity: 0.75, fontSize: '0.8rem' }}>
                    {e.lastGreen ? e.lastGreen.slice(0, 10) : t.never}
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>

      <p style={{ fontSize: '0.88rem', lineHeight: 1.6, opacity: 0.85, margin: '0 0 0.8rem' }}>{t.bad}</p>
      <p style={{ fontSize: '0.88rem', lineHeight: 1.6, opacity: 0.85, margin: 0 }}>{t.good}</p>
    </div>
  )
}
