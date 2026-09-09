import { useI18n } from '../i18n/context'
import { MODULES } from '../lib/queenModules'
import './ModulesBlock.css'

// A compact index of the modules: one card each, linking to its tab. Not on the
// homepage any more — every module has a block of its own there — but kept
// because the data it reads now lives in lib/queenModules and this is the one
// place that shows all of them at a glance.

const COPY = {
  en: {
    eyebrow: 'QUEEN / EIGHT MODULES',
    title: 'One screen, nine ways to read it',
    lede: 'The Queen is a single-page module: the 3D map is the ground and every panel floats on it. These nine are what that ground can be read as — each one opens on the same map, in the same shell, from the key beside it.',
    open: 'Open',
    all: 'Open the shell →',
  },
  ru: {
    eyebrow: 'КОРОЛЕВА / ВОСЕМЬ МОДУЛЕЙ',
    title: 'Один экран и девять способов его прочитать',
    lede: 'Королева — одностраничный модуль: 3D-карта здесь основание, а каждая панель плавает над ним. Эти девять — то, чем это основание можно прочитать; любой открывается на той же карте, в том же шелле, по клавише рядом с ним.',
    open: 'Открыть',
    all: 'Открыть шелл →',
  },
} as const

export default function ModulesBlock() {
  const { lang } = useI18n()
  const key = lang === 'ru' ? 'ru' : 'en'
  const t = COPY[key]

  return (
    <section className="modules-block" id="modules" aria-labelledby="modules-title">
      <div className="modules-block-inner">
        <header className="modules-block-head">
          <span className="modules-block-eyebrow">{t.eyebrow}</span>
          <h2 id="modules-title">{t.title}</h2>
          <p>{t.lede}</p>
        </header>

        <ol className="modules-block-grid">
          {MODULES.map((module) => {
            const m = module[key]
            return (
              <li key={module.tab}>
                <a className="modules-card" href={`#/queen?tab=${module.tab}`}>
                  <span className="modules-card-mark">
                    <i aria-hidden="true">{module.glyph}</i>
                    <b aria-hidden="true">{module.key}</b>
                  </span>
                  <strong>{m.name}</strong>
                  <small>{m.hint}</small>
                  <p>{m.body}</p>
                  <span className="modules-card-open">{t.open} →</span>
                </a>
              </li>
            )
          })}
        </ol>

        <a className="modules-block-all" href="#/queen">
          {t.all}
        </a>
      </div>
    </section>
  )
}
