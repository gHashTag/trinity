import { useCallback, useState } from 'react'
import { QUEEN_WIDGETS } from '../lib/queenWidgets.generated'
import './QueenWidgets.css'

// WIDGETS: what of t27 a person can lift out and share. Every widget, its words and its card
// come from specs/widgets/gallery.t27 through scripts/widgets-from-spec.mjs, which reads each
// widget's own page; this view only draws them and hands out the embed code. It posts nothing:
// every share link opens the reader's own composer.

type Widget = (typeof QUEEN_WIDGETS.widgets)[number]
type Lang = 'en' | 'ru'

const COPY = {
  en: {
    kicker: 'SHAREABLE WIDGETS',
    title: 'WIDGETS',
    lead: 'Real recordings and the in-browser compiler, each with a page of its own. Preview it, embed it in a site or a README, or share it.',
    source: 'SOURCE .T27',
    all: 'All',
    categories: { fpga: 'FPGA bench', compiler: 'Compiler', game: 'Agent game' } as Record<string, string>,
    kinds: { cast: 'recording', player: 'live player', tab: 'board tab' } as Record<string, string>,
    why: 'why share',
    preview: 'Preview',
    hide: 'Hide',
    openTab: 'Open the tab',
    open: 'Open page',
    embed: 'Embed',
    iframe: 'HTML (iframe)',
    markdown: 'Markdown (README)',
    copy: 'Copy',
    copied: 'Copied',
    copyLink: 'Copy link',
    recorded: 'recorded',
    ideas: 'NEXT WIDGETS, NOT BUILT',
    ideasLead: 'What FPGA engineers draw in the browser elsewhere and t27.ai does not draw yet. Each would read data this repository already has.',
    reads: 'would read',
    honesty: 'Nothing here posts for you. The share links open your own X or Telegram composer, and the embed code is yours to paste.',
    count: (n: number) => `${n} widgets`,
  },
  ru: {
    kicker: 'ВИДЖЕТЫ ДЛЯ РЕПОСТА',
    title: 'ВИДЖЕТЫ',
    lead: 'Настоящие записи команд и компилятор прямо в браузере, у каждого своя страница. Посмотрите, вставьте на сайт или в README, поделитесь.',
    source: 'ИСХОДНИК .T27',
    all: 'Все',
    categories: { fpga: 'FPGA-стенд', compiler: 'Компилятор', game: 'Игра агентов' } as Record<string, string>,
    kinds: { cast: 'запись', player: 'живой плеер', tab: 'вкладка доски' } as Record<string, string>,
    why: 'зачем делиться',
    preview: 'Смотреть',
    hide: 'Скрыть',
    openTab: 'Открыть вкладку',
    open: 'Страница',
    embed: 'Встроить',
    iframe: 'HTML (iframe)',
    markdown: 'Markdown (README)',
    copy: 'Копировать',
    copied: 'Скопировано',
    copyLink: 'Ссылка',
    recorded: 'записано',
    ideas: 'СЛЕДУЮЩИЕ ВИДЖЕТЫ, ЕЩЁ НЕ СДЕЛАНЫ',
    ideasLead: 'То, что FPGA-инженеры рисуют в браузере в других местах, а t27.ai пока нет. Каждому хватит данных, которые уже есть в репозитории.',
    reads: 'данные',
    honesty: 'Здесь ничего не публикуется за вас. Ссылки открывают ваш собственный редактор поста в X или Telegram, код для встраивания вставляете вы.',
    count: (n: number) => `${n} виджетов`,
  },
} as const

const ORIGIN = QUEEN_WIDGETS.origin
// The card and the preview load from this site, wherever it is served (t27.ai, or app.t27.ai/game/
// with a relative base); only the addresses a reader copies are absolute.
const local = (url: string) => (url.startsWith(ORIGIN) ? url.slice(ORIGIN.length) : url)

function useCopy() {
  const [done, setDone] = useState<string | null>(null)
  const copy = useCallback(async (key: string, text: string) => {
    try {
      await navigator.clipboard.writeText(text)
      setDone(key)
      window.setTimeout(() => setDone((k) => (k === key ? null : k)), 1400)
    } catch {
      setDone(null)
    }
  }, [])
  return { done, copy }
}

function shareLinks(w: Widget) {
  const u = encodeURIComponent(w.url)
  const text = encodeURIComponent(`${w.title} ${QUEEN_WIDGETS.handle}`)
  const tags = QUEEN_WIDGETS.hashtags.join(',')
  const tg = encodeURIComponent(`${w.title}\n${w.hook}\n\n${QUEEN_WIDGETS.hashtags.map((t) => `#${t}`).join(' ')}`)
  return [
    { name: 'X', href: `https://twitter.com/intent/tweet?url=${u}&text=${text}&hashtags=${tags}` },
    { name: 'Telegram', href: `https://t.me/share/url?url=${u}&text=${tg}` },
  ]
}

function WidgetCard({ w, c }: { w: Widget; c: (typeof COPY)[Lang] }) {
  const [live, setLive] = useState(false)
  const [embed, setEmbed] = useState(false)
  const { done, copy } = useCopy()
  const isPlayer = w.kind === 'player'
  return (
    <article className={`queen-widgets-card is-${w.kind}`} id={`widget-${w.id}`}>
      <div className={`queen-widgets-stage${isPlayer ? ' is-wide' : ''}`}>
        {live && w.preview ? (
          <iframe src={w.preview} title={w.title} loading="lazy" allow="clipboard-write" />
        ) : w.image ? (
          <img src={local(w.image)} alt={w.title} loading="lazy" decoding="async" />
        ) : (
          <span className="queen-widgets-glyph" aria-hidden="true">⚔</span>
        )}
      </div>
      <div className="queen-widgets-body">
        <p className="queen-widgets-tags">
          <span>{c.categories[w.category] ?? w.category}</span>
          <span>{c.kinds[w.kind] ?? w.kind}</span>
          {w.recorded ? <span>{c.recorded} {w.recorded.slice(0, 10)}</span> : null}
        </p>
        <h4>{w.title}</h4>
        <p className="queen-widgets-line">{w.line}</p>
        <p className="queen-widgets-hook"><b>{c.why}</b> {w.hook}</p>
        <div className="queen-widgets-actions">
          {w.preview ? (
            <button type="button" onClick={() => setLive((v) => !v)} aria-pressed={live}>{live ? c.hide : c.preview}</button>
          ) : w.view ? (
            <a href={`#/queen?tab=${w.view}`}>{c.openTab}</a>
          ) : null}
          <a href={w.url} target="_blank" rel="noopener noreferrer">{c.open}</a>
          <button type="button" onClick={() => setEmbed((v) => !v)} aria-expanded={embed}>{c.embed}</button>
          {shareLinks(w).map((s) => (
            <a key={s.name} href={s.href} target="_blank" rel="noopener noreferrer">{s.name}</a>
          ))}
          <button type="button" onClick={() => copy('link', w.url)}>{done === 'link' ? c.copied : c.copyLink}</button>
        </div>
        {embed ? (
          <div className="queen-widgets-embed">
            {([['iframe', c.iframe, w.iframe], ['markdown', c.markdown, w.markdown]] as const).map(([key, label, code]) => (
              <label key={key}>
                <span>{label}</span>
                <textarea readOnly value={code} rows={key === 'iframe' ? 3 : 2} onFocus={(e) => e.currentTarget.select()} />
                <button type="button" onClick={() => copy(key, code)}>{done === key ? c.copied : c.copy}</button>
              </label>
            ))}
          </div>
        ) : null}
      </div>
    </article>
  )
}

export function QueenWidgets({ lang }: { lang: Lang }) {
  const c = COPY[lang]
  const [shelf, setShelf] = useState<string>('all')
  const shelves = QUEEN_WIDGETS.categories.filter((cat) => shelf === 'all' || cat.id === shelf)
  return (
    <section className="queen-widgets" aria-labelledby="queen-widgets-title">
      <header className="queen-widgets-head">
        <div>
          <p className="queen-widgets-kicker">{c.kicker} · {c.count(QUEEN_WIDGETS.widgets.length)}</p>
          <h3 id="queen-widgets-title">{c.title}</h3>
          <p className="queen-widgets-lead">{c.lead}</p>
        </div>
        <a className="queen-widgets-source" href={QUEEN_WIDGETS.source.publicSpec.replace(/^public\//, '')} target="_blank" rel="noopener noreferrer">{c.source}</a>
      </header>
      <nav className="queen-widgets-filter" aria-label={c.kicker}>
        {[{ id: 'all', name: c.all }, ...QUEEN_WIDGETS.categories.map((cat) => ({ id: cat.id, name: c.categories[cat.id] ?? cat.name }))].map((f) => (
          <button key={f.id} type="button" aria-pressed={shelf === f.id} onClick={() => setShelf(f.id)}>{f.name}</button>
        ))}
      </nav>
      {shelves.map((cat) => (
        <section key={cat.id} className="queen-widgets-shelf" aria-label={c.categories[cat.id] ?? cat.name}>
          <h4 className="queen-widgets-shelf-title">{c.categories[cat.id] ?? cat.name}</h4>
          <p className="queen-widgets-shelf-line">{cat.line}</p>
          <div className="queen-widgets-grid">
            {QUEEN_WIDGETS.widgets.filter((w) => w.category === cat.id).map((w) => <WidgetCard key={w.id} w={w} c={c} />)}
          </div>
        </section>
      ))}
      <section className="queen-widgets-ideas" aria-labelledby="queen-widgets-ideas">
        <h4 id="queen-widgets-ideas" className="queen-widgets-shelf-title">{c.ideas}</h4>
        <p className="queen-widgets-shelf-line">{c.ideasLead}</p>
        <ol>
          {QUEEN_WIDGETS.ideas.map((idea) => (
            <li key={idea.id}>
              <b>{idea.title}</b>
              <span>{idea.line}</span>
              <small>{c.reads}: {idea.source}</small>
            </li>
          ))}
        </ol>
      </section>
      <p className="queen-widgets-honesty">{c.honesty}</p>
    </section>
  )
}

export default QueenWidgets
