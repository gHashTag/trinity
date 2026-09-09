import { useEffect, useRef, useState } from 'react'
import { useI18n } from '../i18n/context'
import { MODULES, type QueenModuleTab } from '../lib/queenModules'
import './ModuleHeroBlock.css'

// A module of the shell, presented the way the hive and the Spec Explorer are:
// a headline, what it shows, the ways in, and then the thing itself at the size
// of a screen. Those two blocks are hand-written because each mounts something
// particular — the live scene, the Explorer — and this one is their shape given
// to every other module, driven by lib/queenModules so that the next module is
// an entry in that list and not another component.
//
// The frame mounts when the block comes near the viewport: a page of shells
// booting at once is a page of everything at once. The observer reports nothing
// in a tab that is open but not displayed, so the rectangle is also read on a
// timer that stops itself — an empty frame is the one state a presentation must
// not have.
const COPY = {
  en: { open: 'Open this module', all: 'Open the shell', frame: 'TRINITY module' },
  ru: { open: 'Открыть модуль', all: 'Открыть шелл', frame: 'Модуль TRINITY' },
} as const

export default function ModuleHeroBlock({ tab }: { tab: QueenModuleTab }) {
  const { lang: rawLang } = useI18n()
  const lang = rawLang === 'ru' ? 'ru' : 'en'
  const t = COPY[lang]
  const module = MODULES.find((m) => m.tab === tab)!
  const m = module[lang]
  const host = useRef<HTMLDivElement>(null)
  const [near, setNear] = useState(() => typeof IntersectionObserver === 'undefined')

  useEffect(() => {
    const node = host.current
    if (!node || near) return
    const watch = new IntersectionObserver(
      (entries) => entries.forEach((entry) => entry.isIntersecting && setNear(true)),
      { rootMargin: '320px' },
    )
    watch.observe(node)
    const poll = window.setInterval(() => {
      const box = node.getBoundingClientRect()
      if (box.top < window.innerHeight + 320 && box.bottom > -320) {
        window.clearInterval(poll)
        setNear(true)
      }
    }, 400)
    return () => {
      watch.disconnect()
      window.clearInterval(poll)
    }
  }, [near])

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
        <div className="module-hero-frame" ref={host}>
          {near ? (
            <iframe
              title={`${t.frame} — ${m.name}`}
              // ?lang= in the search, where the provider reads it: a frame is
              // its own document and does not hear the parent's switch.
              src={`./?lang=${lang}#/queen?tab=${tab}&embed=1`}
              loading="lazy"
              sandbox="allow-scripts allow-same-origin"
            />
          ) : null}
        </div>
      </div>
    </section>
  )
}
