import { useI18n } from '../i18n/context'

const TELEGRAM_URL = 'https://t.me/t27ai_bot?start=website'

const copy = {
  en: {
    eyebrow: 'TRINITY S3AI SERVICE',
    title: 'Continue with your own Telegram identity',
    body: 'The agent works only inside a verified Telegram profile. The website does not create a parallel account, expose credentials, or let one user act as another.',
    telegram: 'Open in Telegram',
    browser: 'Try in browser',
    browserNote: 'Browser access will appear here after the owner confirms a stable public Mini App URL.',
  },
  ru: {
    eyebrow: 'СЕРВИС TRINITY S3AI',
    title: 'Продолжите со своим профилем Telegram',
    body: 'Агент работает только внутри подтверждённого профиля Telegram. Сайт не создаёт параллельную учётную запись, не раскрывает ключи и не позволяет действовать от имени другого пользователя.',
    telegram: 'Открыть в Telegram',
    browser: 'Попробовать в браузере',
    browserNote: 'Вход из браузера появится здесь после подтверждения владельцем стабильного публичного URL Mini App.',
  },
}

export default function ServiceEntry() {
  const { lang } = useI18n()
  const t = copy[lang === 'ru' ? 'ru' : 'en']

  return (
    <section className="tnf-section" aria-labelledby="service-entry-title" style={{ paddingTop: 0 }}>
      <div className="tnf-wrap">
        <div className="tnf-cell" style={{ padding: 'clamp(var(--sp2), 5vw, var(--sp3))' }}>
          <span className="tnf-badge" style={{ color: 'var(--accent)' }}>{t.eyebrow}</span>
          <h2 id="service-entry-title" className="tnf-h2" style={{ marginTop: 'var(--sp0)' }}>{t.title}</h2>
          <p className="tnf-lede" style={{ marginBottom: 'var(--sp2)' }}>{t.body}</p>

          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 'var(--sp0)', alignItems: 'center' }}>
            <a
              className="btn"
              href={TELEGRAM_URL}
              target="_blank"
              rel="noopener noreferrer"
              aria-label={`${t.telegram} — @t27ai_bot`}
            >
              {t.telegram}
            </a>
            <button type="button" className="btn secondary" disabled style={{ cursor: 'not-allowed', opacity: 0.55 }}>
              {t.browser}
            </button>
          </div>
          <p style={{ color: 'var(--muted)', fontSize: 'var(--f-1)', margin: 'var(--sp0) 0 0', maxWidth: '68ch' }}>
            {t.browserNote}
          </p>
        </div>
      </div>
    </section>
  )
}
