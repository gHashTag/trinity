import { useState } from 'react'
import { useI18n } from '../i18n/context'
import { MODULES, type QueenModuleTab } from '../lib/queenModules'
import PlayLine from './PlayLine'
import './ModuleHeroBlock.css'

// A module of the shell, presented the way the hive and the Spec Explorer are:
// a headline, what it shows, the ways in, and then the thing itself at the size
// of a screen. Those two blocks are hand-written because each mounts something
// particular — the live scene, the Explorer — and this one is their shape given
// to every other module, driven by lib/queenModules so that the next module is
// an entry in that list and not another component.
//
// The frame is the whole board booted a second time, so it mounts when the
// reader asks for it, not when the block scrolls near. It used to mount on
// approach, and a reader who scrolled the home once booted three boards and the
// Explorer beside the page's own: 218 requests, about 8 MB, and every board
// polling the supervisor (measured on t27.ai, 2026-10-04). Until then the frame
// shows what it holds and the one button that runs it -- never an empty box.
const COPY = {
  en: { open: 'Open this module', all: 'Open the shell', frame: 'TRINITY module', run: 'Run it here', note: 'The live module is the whole board in a frame, so it loads only when you ask.' },
  ru: { open: 'Открыть модуль', all: 'Открыть шелл', frame: 'Модуль TRINITY', run: 'Запустить здесь', note: 'Живой модуль — это весь борд во фрейме, поэтому он грузится только по вашей просьбе.' },
} as const

export default function ModuleHeroBlock({ tab }: { tab: QueenModuleTab }) {
  const { lang: rawLang } = useI18n()
  const lang = rawLang === 'ru' ? 'ru' : 'en'
  const t = COPY[lang]
  const module = MODULES.find((m) => m.tab === tab)!
  const m = module[lang]
  const [running, setRunning] = useState(false)

  return (
    <section className="module-hero" aria-labelledby={`module-hero-${tab}`}>
      <div className="module-hero-inner">
        <div className="module-hero-copy">
          <div className="module-hero-lede">
            <span className="module-hero-eyebrow">
              <i aria-hidden="true">{module.glyph}</i>
              {m.name}
              <b aria-hidden="true">{module.key}</b>
            </span>
            <h2 id={`module-hero-${tab}`}>{m.hint}</h2>
          </div>
          <div className="module-hero-aside">
            <p>{m.body}</p>
            <PlayLine>{m.play}</PlayLine>
            <div className="module-hero-actions">
              <a className="module-hero-primary" href={`#/queen?tab=${tab}`}>
                {t.open}
              </a>
              <a className="module-hero-secondary" href="#/queen">
                {t.all}
              </a>
            </div>
          </div>
        </div>
        <div className="module-hero-frame">
          {running ? (
            <iframe
              title={`${t.frame} — ${m.name}`}
              // ?lang= in the search, where the provider reads it: a frame is
              // its own document and does not hear the parent's switch.
              src={`./?lang=${lang}#/queen?tab=${tab}&embed=1`}
              sandbox="allow-scripts allow-same-origin"
            />
          ) : (
            <button type="button" className="module-hero-run" onClick={() => setRunning(true)}>
              <i aria-hidden="true">{module.glyph}</i>
              <span>{t.run} ▸</span>
              <small>{t.note}</small>
            </button>
          )}
        </div>
      </div>
    </section>
  )
}
