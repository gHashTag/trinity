import { useEffect, useState } from 'react'
import { useI18n } from '../i18n/context'
import { MODULES } from '../lib/queenModules'
import { specExplorerHash } from '../lib/specCatalog'
import { loadManifest } from '../lib/t27Compiler'
import PlayLine from './PlayLine'
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
    all: 'All specs',
    open: 'Open this spec full screen',
    frame: 'T27 Spec Explorer',
  },
  ru: {
    eyebrow: 'T27 / ИСТОЧНИК',
    title: 'Вот что такое спека .t27',
    body: 'hello_world.t27 — самая маленькая спека, в которой видна каждая часть языка: константы, тип, функции, тест и инвариант. Здесь её компилирует настоящий компилятор, а не цитата.',
    all: 'Все спеки',
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
  // The count is the Spec Explorer's own: the same manifest through the same
  // loader, in the shape its category list prints, so this link and the page it
  // opens cannot disagree. It was the literal 760 and stayed 760 while the
  // corpus grew to 856. Until the manifest answers, the link carries no number.
  const [specCount, setSpecCount] = useState<number | null>(null)
  useEffect(() => {
    let alive = true
    loadManifest().then((manifest) => { if (alive) setSpecCount(manifest.specCount) }).catch(() => {})
    return () => { alive = false }
  }, [])

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
            {/* As in the comb's block: this block writes its own description
                because it mounts the Explorer itself, but the move belongs to
                the module record. */}
            <PlayLine>{MODULES.find((module) => module.tab === 'specs')![lang].play}</PlayLine>
            <div className="spec-hero-block-actions">
              <a className="spec-hero-block-primary" href={full}>{t.open}</a>
              <a className="spec-hero-block-secondary" href="#/specs">{specCount === null ? t.all : `${t.all} (${specCount})`}</a>
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
