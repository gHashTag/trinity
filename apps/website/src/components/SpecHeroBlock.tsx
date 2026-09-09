import { useI18n } from '../i18n/context'
import { specExplorerHash } from '../lib/specCatalog'
import './SpecHeroBlock.css'

// The landing shows the Spec Explorer itself, the same way the Queen inspector
// does: an iframe at ?embed=1 rather than a second source viewer. The path goes
// through specExplorerHash, so it is validated and fails closed exactly like
// every other link into the catalog.
const LANDING_SPEC = 'specs/demos/hello_world.t27'

const copy = {
  en: {
    eyebrow: 'T27 / SOURCE',
    title: 'This is what a .t27 spec is',
    body: 'hello_world.t27 is the smallest spec that still shows every part of the language: constants, a type, functions, a test and an invariant. It is compiled here by the real compiler, not quoted.',
    all: 'All 760 specs',
    open: 'Open this spec full screen',
    frame: 'T27 Spec Explorer',
  },
  ru: {
    eyebrow: 'T27 / ИСТОЧНИК',
    title: 'Вот что такое спека .t27',
    body: 'hello_world.t27 — самая маленькая спека, в которой видна каждая часть языка: константы, тип, функции, тест и инвариант. Здесь её компилирует настоящий компилятор, а не цитата.',
    all: 'Все 760 спек',
    open: 'Открыть спеку на весь экран',
    frame: 'Обозреватель спецификаций T27',
  },
} as const

export default function SpecHeroBlock() {
  const { lang: rawLang } = useI18n()
  const lang = rawLang === 'ru' ? 'ru' : 'en'
  const t = copy[lang]
  const embedded = specExplorerHash(LANDING_SPEC, { embedded: true })
  const full = specExplorerHash(LANDING_SPEC)

  return (
    <section className="spec-hero-block" aria-labelledby="spec-hero-title">
      <div className="spec-hero-block-inner">
        <div className="spec-hero-block-copy">
          <div className="spec-hero-block-lede">
            <span className="spec-hero-block-eyebrow">{t.eyebrow}</span>
            <h2 id="spec-hero-title">{t.title}</h2>
          </div>
          <div className="spec-hero-block-aside">
            <p>{t.body}</p>
            <div className="spec-hero-block-actions">
              <a className="spec-hero-block-primary" href={full}>{t.open}</a>
              <a className="spec-hero-block-secondary" href="#/specs">{t.all}</a>
            </div>
          </div>
        </div>
        <div className="spec-hero-block-frame">
          <iframe
            title={t.frame}
            // The language rides in the search, not the hash: the provider reads
            // ?lang= from location.search, and a frame is a document of its own
            // — it booted with whatever localStorage said at the time and never
            // heard the switch. Binding it to the parent's choice also reloads
            // the frame when that choice changes, because the src changes.
            src={`./?lang=${lang}${embedded}`}
            loading="lazy"
            sandbox="allow-scripts allow-same-origin"
            allow="clipboard-write"
          />
        </div>
      </div>
    </section>
  )
}
