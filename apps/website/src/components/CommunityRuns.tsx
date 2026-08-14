"use client";
import { useI18n } from '../i18n/context'
import community from '../data/communityRuns.json'

// Who is using the check, discovered rather than listed.
//
// Every other run on this page is one I chose to show, which makes that part of
// the page a portfolio. This part is not curated: a nightly job asks GitHub
// which public repositories name the reusable workflow in .github/workflows/,
// reads each one's own latest run conclusion from the API, and writes the
// answer here. I cannot leave a failed run out of it without deleting the job.
//
// Today the answer is one repository and it is mine. Saying so is the only
// version of this section worth publishing: a gallery that hides its size is
// back to being a portfolio with extra steps.

type Entry = {
  repo: string
  workflow: string
  tops: string[]
  conclusion: string | null
  runUrl: string
  sha: string
  at: string
}

const ENTRIES = (community.entries ?? []) as Entry[]
const MINE = ENTRIES.filter((e) => e.repo.toLowerCase().startsWith('ghashtag/')).length
const OTHERS = ENTRIES.length - MINE

const T = {
  en: {
    h2: 'Who is using the check',
    lede:
      'Not a list I keep. A nightly job asks GitHub which public repositories name the reusable workflow in their own .github/workflows/, then reads each one’s latest run conclusion from the API. A failed run cannot be left out of this without deleting the job that writes it.',
    countMine: (n: number) => `${n} repositor${n === 1 ? 'y' : 'ies'}, mine`,
    countOthers: (n: number) => `${n} repositor${n === 1 ? 'y' : 'ies'}, not mine`,
    honest:
      'Every repository here today is mine. That is what the number is, and a section that hid it would be a portfolio with extra steps — the thing this one exists to stop being.',
    empty: 'No repository outside this account has run the check yet.',
    designs: 'Designs checked',
    latest: 'Latest run',
    note:
      'The conclusion is the run’s own, read from the API. It says the checks passed in that repository — not that the design is correct, which no run at this tier establishes.',
  },
  ru: {
    h2: 'Кто пользуется проверкой',
    lede:
      'Это не список, который я веду. Ночная задача спрашивает у GitHub, какие публичные репозитории называют переиспользуемый воркфлоу в своём .github/workflows/, и читает вывод последнего прогона каждого через API. Упавший прогон нельзя отсюда убрать, не удалив саму задачу.',
    countMine: (n: number) => `${n} — мои`,
    countOthers: (n: number) => `${n} — не мои`,
    honest:
      'Сегодня все репозитории здесь — мои. Это и есть цифра; секция, которая её прячет, была бы витриной с лишними шагами — ровно тем, чем эта перестаёт быть.',
    empty: 'Ни один репозиторий вне этого аккаунта пока не запускал проверку.',
    designs: 'Проверенные дизайны',
    latest: 'Последний прогон',
    note:
      'Вывод — собственный вывод прогона, прочитанный через API. Он значит, что проверки прошли в том репозитории, а не что дизайн верен: на этой ступени этого не устанавливает ни один прогон.',
  },
}

export default function CommunityRuns() {
  const { lang } = useI18n()
  const t = lang === 'ru' ? T.ru : T.en

  return (
    <div className="premium-card" style={{ textAlign: 'left', marginBottom: '2.5rem' }}>
      <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginTop: 0, marginBottom: '0.6rem' }}>{t.h2}</h2>
      <p style={{ fontSize: '0.95rem', lineHeight: 1.65, opacity: 0.88, maxWidth: '68ch', margin: '0 0 1.1rem' }}>{t.lede}</p>

      <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.5rem 1.5rem', marginBottom: '1.1rem' }}>
        <span style={{ fontSize: '0.85rem', opacity: 0.8 }}>{t.countMine(MINE)}</span>
        <span style={{ fontSize: '0.85rem', opacity: 0.8 }}>{t.countOthers(OTHERS)}</span>
      </div>

      {OTHERS === 0 && (
        <p style={{
          margin: '0 0 1.1rem', padding: '0.8rem 1rem', borderRadius: '10px',
          background: 'rgba(255,255,255,0.04)', border: '1px solid var(--border)',
          fontSize: '0.88rem', lineHeight: 1.6,
        }}>
          {t.honest}
        </p>
      )}

      {ENTRIES.length === 0 ? (
        <p style={{ fontSize: '0.9rem', opacity: 0.75, margin: 0 }}>{t.empty}</p>
      ) : (
        <div style={{ display: 'grid', gap: '0.7rem' }}>
          {ENTRIES.map((e) => (
            <div key={e.repo} style={{ borderLeft: '2px solid var(--accent)', paddingLeft: '0.9rem' }}>
              <a
                href={`https://github.com/${e.repo}`}
                target="_blank"
                rel="noopener noreferrer"
                style={{ fontWeight: 700, color: 'var(--accent)', textDecoration: 'none', fontSize: '0.98rem' }}
              >
                {e.repo}
              </a>
              <p style={{ margin: '0.25rem 0 0', fontSize: '0.86rem', opacity: 0.85, lineHeight: 1.55 }}>
                {t.designs}: {e.tops.length ? e.tops.join(', ') : '—'}
              </p>
              <p style={{ margin: '0.15rem 0 0', fontSize: '0.82rem', opacity: 0.7 }}>
                {t.latest}:{' '}
                <a href={e.runUrl} target="_blank" rel="noopener noreferrer" style={{ color: 'inherit' }}>
                  {e.conclusion ?? 'unknown'} · {e.sha} · {e.at?.slice(0, 10)}
                </a>
              </p>
            </div>
          ))}
        </div>
      )}

      <p style={{ margin: '1.1rem 0 0', fontSize: '0.84rem', lineHeight: 1.6, opacity: 0.72 }}>{t.note}</p>
    </div>
  )
}
