import Navigation from '../components/Navigation'
import Footer from '../components/Footer'
import { useI18n } from '../i18n/context'
import {
  papers,
  datasets,
  upstream,
  channels,
  identities,
  retractions,
  discrepancies,
  allResources,
  CORPUS_VERIFIED,
  type Resource,
} from '../data/resources'

/* Страница была пятью подряд плотными таблицами на ~11px, целиком по-английски
   при любом языке интерфейса: ни одного визуального якоря, ни счёта, ни навигации.
   Ресурс — это карточка (ссылка, идентификатор, дата проверки, состояние), а не
   строка таблицы: карточки не требуют горизонтальной прокрутки на телефоне и держат
   читаемый кегль. Заголовки и подписи переведены; названия статей, DOI и хэндлы
   остаются на языке оригинала — это идентификаторы, их перевод был бы ошибкой. */

const wrap: React.CSSProperties = {
  maxWidth: '900px',
  margin: '0 auto',
  padding: '120px 24px 80px',
}

const dim = 'var(--text-dim, #8a8a8a)'
const border = 'var(--border, #2a2a2a)'
const accent = 'var(--accent, #d4af37)'

type Lang = 'ru' | 'en'

const STATUS_LABEL: Record<Resource['status'], Record<Lang, string>> = {
  live: { ru: 'открыт', en: 'live' },
  broken: { ru: 'не открылся', en: 'broken' },
  unverified: { ru: 'не проверен', en: 'unverified' },
}

function noteFor(r: Resource, lang: Lang): string | undefined {
  return lang === 'ru' ? (r.noteRu ?? r.note) : r.note
}

const COPY = {
  title: { ru: 'Ресурсы', en: 'Resources' },
  lede: {
    ru: 'Канонический список всех публичных ресурсов корпуса: статьи, DOI, патчи в апстрим, каналы, идентификаторы. Всё, что сказано в другом месте — профиль GitHub, LinkedIn, слайды, — сверяется с этой страницей, а не наоборот.',
    en: 'The canonical list of every public resource in this corpus — papers, DOIs, upstream patches, channels, identities. Anything stated elsewhere (GitHub profile, LinkedIn, slide decks) is reconciled against this page, not the other way round.',
  },
  ledeTwo: {
    ru: 'У каждой записи стоит дата, когда её последний раз открывали. Дата не обновляется, пока ресурс действительно не открыли заново. Последний обход корпуса:',
    en: 'Each entry carries the date it was last checked against the live resource. An entry is not re-dated unless someone actually re-opened it. Corpus last swept:',
  },
  totalLabel: { ru: 'записей всего', en: 'entries in total' },
  liveLabel: { ru: 'открылись при проверке', en: 'opened when checked' },
  discrepancyLabel: { ru: 'расхождений', en: 'discrepancies' },
  discrepancyTitle: { ru: 'Известные расхождения', en: 'Known discrepancies' },
  discrepancyLede: {
    ru: 'Опубликованы здесь, а не исправлены молча: кто нашёл неверную версию в другом месте, должен видеть, какая из них верна.',
    en: 'Published here rather than quietly fixed, so that anyone who found the wrong version elsewhere can see which one is right.',
  },
  verifiedPrefix: { ru: 'проверено', en: 'checked' },
  sections: {
    papers: { ru: 'Статьи (arXiv)', en: 'Papers (arXiv)' },
    datasets: { ru: 'Данные и ПО (DOI на Zenodo)', en: 'Datasets & software (Zenodo DOI)' },
    upstream: { ru: 'Вклад в апстрим — openXC7 / nextpnr-xilinx', en: 'Upstream contributions — openXC7 / nextpnr-xilinx' },
    channels: { ru: 'Каналы', en: 'Channels' },
    identities: { ru: 'Идентификаторы и контакты', en: 'Identities & contact' },
    retractions: { ru: 'Отозванные утверждения', en: 'Withdrawn claims' },
  },
} as const

function badge(status: Resource['status']): React.CSSProperties {
  return {
    display: 'inline-block',
    fontSize: '0.82rem',
    letterSpacing: '0.04em',
    padding: '2px 9px',
    borderRadius: '4px',
    border: `1px solid ${status === 'broken' ? '#c0392b' : status === 'live' ? accent : border}`,
    color: status === 'broken' ? '#e06055' : status === 'live' ? accent : dim,
    whiteSpace: 'nowrap',
    flexShrink: 0,
  }
}

function Group({
  id,
  title,
  rows,
  lang,
}: {
  id: string
  title: string
  rows: Resource[]
  lang: Lang
}) {
  return (
    /* Глобальное правило `section` даёт min-height 60vh, центрирование по вертикали
       и text-align: center — вложенная секция превращалась в экран пустоты с
       заголовком и названиями карточек по центру. Здесь нужен обычный блок. */
    <div id={id} style={{ marginBottom: '3.2em', scrollMarginTop: '110px', textAlign: 'left' }}>
      <h2
        style={{
          fontSize: '1.25rem',
          marginBottom: '0.2em',
          display: 'flex',
          alignItems: 'baseline',
          gap: '0.6rem',
          flexWrap: 'wrap',
        }}
      >
        {title}
        <span style={{ color: dim, fontSize: '0.9rem', fontWeight: 400 }}>{rows.length}</span>
      </h2>
      <div style={{ display: 'grid', gap: '10px', marginTop: '1.1em' }}>
        {rows.map((r) => (
          <article
            key={r.href}
            style={{
              border: `1px solid ${border}`,
              borderRadius: '8px',
              padding: '14px 16px',
              background: 'rgba(255, 255, 255, 0.02)',
            }}
          >
            <div
              style={{
                display: 'flex',
                gap: '12px',
                alignItems: 'baseline',
                justifyContent: 'space-between',
                flexWrap: 'wrap',
              }}
            >
              <a
                href={r.href}
                target="_blank"
                rel="noopener noreferrer"
                style={{ fontSize: '0.95rem', lineHeight: 1.5, flex: '1 1 320px' }}
              >
                {r.title}
              </a>
              <span style={badge(r.status)}>{STATUS_LABEL[r.status][lang]}</span>
            </div>

            <div
              style={{
                display: 'flex',
                gap: '14px',
                flexWrap: 'wrap',
                marginTop: '8px',
                color: dim,
                fontSize: '0.85rem',
              }}
            >
              {r.id && <code style={{ fontSize: '0.85rem', color: dim }}>{r.id}</code>}
              <span>
                {COPY.verifiedPrefix[lang]} {r.verified}
              </span>
            </div>

            {noteFor(r, lang) && (
              <p
                style={{
                  color: dim,
                  fontSize: '0.88rem',
                  lineHeight: 1.65,
                  margin: '9px 0 0',
                  maxWidth: 'none',
                  textAlign: 'left',
                }}
              >
                {noteFor(r, lang)}
              </p>
            )}
          </article>
        ))}
      </div>
    </div>
  )
}

export default function Resources() {
  const { lang: rawLang } = useI18n()
  const lang: Lang = rawLang === 'ru' ? 'ru' : 'en'

  const bad = discrepancies()
  const all = allResources()
  const liveCount = all.filter((r) => r.status === 'live').length

  const groups: { id: keyof typeof COPY.sections; rows: Resource[] }[] = [
    { id: 'papers', rows: papers },
    { id: 'datasets', rows: datasets },
    { id: 'upstream', rows: upstream },
    { id: 'channels', rows: channels },
    { id: 'identities', rows: identities },
    /* Список отзывов лежал в данных и попадал в счёт, но не был ни одной секцией
       на странице: страница обещала публиковать отозванное и не публиковала. */
    { id: 'retractions', rows: retractions },
  ]

  return (
    <main>
      <Navigation />
      <div style={wrap}>
        <h1 style={{ marginBottom: '0.3em' }}>{COPY.title[lang]}</h1>
        <p style={{ color: dim, lineHeight: 1.75, marginBottom: '0.6em', maxWidth: 'none', textAlign: 'left' }}>
          {COPY.lede[lang]}
        </p>
        <p style={{ color: dim, lineHeight: 1.75, maxWidth: 'none', textAlign: 'left' }}>
          {COPY.ledeTwo[lang]} <strong>{CORPUS_VERIFIED}</strong>.
        </p>

        {/* Счёт вместо стены строк: сколько всего, сколько открылось, сколько расхождений. */}
        <div
          style={{
            display: 'flex',
            gap: '28px',
            flexWrap: 'wrap',
            border: `1px solid ${border}`,
            borderRadius: '10px',
            padding: '18px 20px',
            margin: '2em 0 0',
          }}
        >
          {[
            { n: all.length, label: COPY.totalLabel[lang], color: 'var(--text)' },
            { n: liveCount, label: COPY.liveLabel[lang], color: accent },
            { n: bad.length, label: COPY.discrepancyLabel[lang], color: bad.length ? '#e06055' : dim },
          ].map((s) => (
            <div key={s.label} style={{ minWidth: '120px' }}>
              <div style={{ fontSize: '1.7rem', lineHeight: 1.1, color: s.color }}>{s.n}</div>
              <div style={{ color: dim, fontSize: '0.85rem', marginTop: '4px' }}>{s.label}</div>
            </div>
          ))}
        </div>

        {/* Навигация по разделам: страница длинная, без якорей её приходится крутить целиком. */}
        <nav style={{ display: 'flex', gap: '10px', flexWrap: 'wrap', margin: '1.2em 0 2.6em' }}>
          {groups.map((g) => (
            <a
              key={g.id}
              href={`#${g.id}`}
              style={{
                fontSize: '0.85rem',
                color: dim,
                border: `1px solid ${border}`,
                borderRadius: '999px',
                padding: '6px 14px',
                textDecoration: 'none',
              }}
            >
              {COPY.sections[g.id][lang]} <span style={{ opacity: 0.65 }}>{g.rows.length}</span>
            </a>
          ))}
        </nav>

        {bad.length > 0 && (
          <div
            style={{
              textAlign: 'left',
              border: `1px solid ${border}`,
              borderLeft: '3px solid #c0392b',
              borderRadius: '8px',
              padding: '18px 20px',
              margin: '0 0 3em',
            }}
          >
            <h2 style={{ fontSize: '1.05rem', margin: '0 0 10px' }}>
              {COPY.discrepancyTitle[lang]} — {bad.length}
            </h2>
            <p style={{ marginTop: 0, lineHeight: 1.7, color: dim, maxWidth: 'none', textAlign: 'left' }}>
              {COPY.discrepancyLede[lang]}
            </p>
            <ul style={{ margin: 0, paddingLeft: '1.2em', lineHeight: 1.7, fontSize: '0.9rem' }}>
              {bad.map((r) => (
                <li key={r.href} style={{ marginBottom: '0.55em' }}>
                  <a href={r.href} target="_blank" rel="noopener noreferrer">
                    {r.title}
                  </a>
                  {noteFor(r, lang) && <span style={{ color: dim }}> — {noteFor(r, lang)}</span>}
                </li>
              ))}
            </ul>
          </div>
        )}

        {groups.map((g) => (
          <Group key={g.id} id={g.id} title={COPY.sections[g.id][lang]} rows={g.rows} lang={lang} />
        ))}
      </div>
      <Footer />
    </main>
  )
}
