import { useState } from 'react'
import { useI18n } from '../i18n/context'
import { useCorpus } from '../lib/queenCorpus'
import { MODULES } from '../lib/queenModules'
import { specExplorerHash } from '../lib/specCatalog'
import PlayLine from './PlayLine'
import './SpecHeroBlock.css'

// The landing shows the Spec Explorer itself, the same way the Queen inspector
// does: an iframe at ?embed=1 rather than a second source viewer. The path goes
// through specExplorerHash, so it is validated and fails closed exactly like
// every other link into the catalog.
//
// The Explorer is a whole application with the compiler's WebAssembly behind
// it, so it boots when the reader asks, not when the block scrolls near: see
// ModuleHeroBlock for the measurement that moved both.
const LANDING_SPEC = 'specs/demos/hello_world.t27'

const copy = {
  en: {
    eyebrow: 'T27 / SOURCE',
    title: 'This is what a .t27 spec is',
    body: 'hello_world.t27 is the smallest spec that still shows every part of the language: constants, a type, functions, a test and an invariant. Run it below and the real compiler builds it in this page; nothing is quoted.',
    all: 'All specs',
    open: 'Open this spec full screen',
    frame: 'T27 Spec Explorer',
    run: 'Compile it here',
    note: 'The Explorer loads the compiler into this page, so it starts only when you ask.',
  },
  ru: {
    eyebrow: 'T27 / ИСТОЧНИК',
    title: 'Вот что такое спека .t27',
    body: 'hello_world.t27 — самая маленькая спека, в которой видна каждая часть языка: константы, тип, функции, тест и инвариант. Запустите её ниже, и настоящий компилятор соберёт её прямо на этой странице, а не процитирует.',
    all: 'Все спеки',
    open: 'Открыть спеку на весь экран',
    frame: 'Обозреватель спецификаций T27',
    run: 'Скомпилировать здесь',
    note: 'Обозреватель загружает компилятор в эту страницу, поэтому запускается только по вашей просьбе.',
  },
} as const

export default function SpecHeroBlock() {
  const { lang: rawLang } = useI18n()
  const lang = rawLang === 'ru' ? 'ru' : 'en'
  const t = copy[lang]
  const embedded = specExplorerHash(LANDING_SPEC, { embedded: true })
  const full = specExplorerHash(LANDING_SPEC)
  // The count is the corpus's own, from the store every tab reads. It was the
  // literal 760 and stayed 760 while the corpus grew to 856. It is read from
  // the atlas the hive above already loaded, not from the 2 MB manifest a
  // second time: qa/queen-spec-sync-contract.mjs fails when the atlas lists one
  // spec more or fewer than the manifest, so the two cannot disagree. Until the
  // atlas answers, the link carries no number.
  const specCount = useCorpus('atlas').part?.data.specs.length ?? null
  const [running, setRunning] = useState(false)
  const glyph = MODULES.find((module) => module.tab === 'specs')!.glyph

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
          {running ? (
            <iframe
              title={t.frame}
              // The language rides in the search, not the hash: the provider reads
              // ?lang= from location.search, and a frame is a document of its own
              // — it booted with whatever localStorage said at the time and never
              // heard the switch. Binding it to the parent's choice also reloads
              // the frame when that choice changes, because the src changes.
              src={`./?lang=${lang}${embedded}`}
              sandbox="allow-scripts allow-same-origin"
              allow="clipboard-write"
            />
          ) : (
            <button type="button" className="spec-hero-block-run" onClick={() => setRunning(true)}>
              <i aria-hidden="true">{glyph}</i>
              <code>{LANDING_SPEC}</code>
              <span>{t.run} ▸</span>
              <small>{t.note}</small>
            </button>
          )}
        </div>
      </div>
    </section>
  )
}
