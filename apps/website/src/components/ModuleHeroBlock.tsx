import { useEffect, useRef, useState } from 'react'
import { useI18n } from '../i18n/context'
import { MODULES, type QueenModuleTab } from '../lib/queenModules'
import './ModuleHeroBlock.css'

// A module of the shell, shown on the homepage the way the hive and the Spec
// Explorer are: the thing itself, in a frame, not a picture of it. The shell
// answers ?tab= for which module and ?embed=1 for the chrome it should leave
// out — so this block is one iframe and its own words, and it cannot drift from
// what the module actually does, because it is what the module actually does.
//
// The frame is mounted when the block comes near the viewport, not on load.
// Four shells booting at once on a landing page is four of everything: four
// board fetches, four intervals, four React trees. Near the fold they are one
// at a time, and above it there is nothing to pay for at all.
const COPY = {
  en: { open: 'Open this module', frame: 'TRINITY module' },
  ru: { open: 'Открыть модуль', frame: 'Модуль TRINITY' },
} as const

export default function ModuleHeroBlock({ tab }: { tab: QueenModuleTab }) {
  const { lang: rawLang } = useI18n()
  const lang = rawLang === 'ru' ? 'ru' : 'en'
  const t = COPY[lang]
  const module = MODULES.find((m) => m.tab === tab)!
  const m = module[lang]
  const host = useRef<HTMLDivElement>(null)
  // No observer, no problem: the frame mounts immediately rather than never.
  // Decided here rather than in the effect, where setting state synchronously
  // is a render the browser has not painted yet.
  const [near, setNear] = useState(() => typeof IntersectionObserver === 'undefined')

  useEffect(() => {
    const node = host.current
    if (!node || near) return
    const watch = new IntersectionObserver(
      (entries) => entries.forEach((entry) => entry.isIntersecting && setNear(true)),
      { rootMargin: '320px' },
    )
    watch.observe(node)
    // A second opinion, asked repeatedly. An observer needs the page laid out
    // and painted to report anything, and a tab that is open but not displayed
    // does neither — measured here: every block scrolled into view and not one
    // frame mounted. A single check at mount is no better, because at mount the
    // block is far below the fold and the answer is correctly "not yet". So the
    // rectangle is read on a timer until it says yes, and the timer stops
    // itself. Timers run in a hidden tab; the rectangle is true there too.
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
        <header className="module-hero-copy">
          <span className="module-hero-eyebrow">
            <i aria-hidden="true">{module.glyph}</i>
            {m.name}
            <b aria-hidden="true">{module.key}</b>
          </span>
          <h2 id={`module-hero-${tab}`}>{m.hint}</h2>
          <p>{m.body}</p>
          <a className="module-hero-open" href={`#/queen?tab=${tab}`}>
            {t.open} →
          </a>
        </header>
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
