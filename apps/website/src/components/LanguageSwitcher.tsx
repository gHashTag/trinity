import { memo, useState, useRef, useEffect } from 'react'
import { createPortal } from 'react-dom'
import { useI18n } from '../i18n/context'

const flags: Record<string, string> = {
  en: '🇺🇸',
  ru: '🇷🇺',
  de: '🇩🇪',
  zh: '🇨🇳',
  es: '🇪🇸'
}

const labels: Record<string, string> = {
  en: 'EN',
  ru: 'RU',
  de: 'DE',
  zh: '中文',
  es: 'ES'
}

const langNames: Record<string, string> = {
  en: 'English',
  ru: 'Russian',
  de: 'German',
  zh: 'Chinese',
  es: 'Spanish'
}

const LANGS = ['en', 'ru', 'de', 'zh', 'es']

export default memo(function LanguageSwitcher() {
  const { lang, setLang } = useI18n()
  const [open, setOpen] = useState(false)
  const buttonRef = useRef<HTMLButtonElement>(null)
  const listRef = useRef<HTMLDivElement>(null)
  // Coordinates used only when an ancestor would clip the dropdown.
  const [fixedPos, setFixedPos] = useState<
    { top?: number; bottom?: number; right: number; minWidth: number } | null>(null)

  // The dock this switcher normally sits in is `overflow-x: auto`, and CSS turns
  // the other axis into `auto` too whenever one axis is not `visible`. The dock
  // is 38px tall and the dropdown opens at `top: 100%`, so the browser clipped
  // it away completely: measured on the live site, 121px of it below the dock's
  // edge, scrollHeight 158 against clientHeight 36, and elementFromPoint at its
  // centre returning the page behind it. It rendered at full opacity and could
  // be neither seen nor clicked — reported as "the language modal does not open"
  // when in fact it opened every time.
  //
  // `position: fixed` alone does NOT escape it. `.nav-dock` also carries
  // `transform: translateX(-50%)`, and a transformed ancestor becomes the
  // containing block for fixed descendants — measured on the live page, the
  // element asked for `top: 57px` and landed at 82, still inside the clip. The
  // only reliable escape is a portal to <body>, so that is what happens when an
  // ancestor clips — which, contrary to what this comment claimed for one day,
  // includes the mobile menu: `.mobile-menu` is `overflow-y: auto`. So the
  // portal fires there too and cancels the upward-opening
  // `.mobile-menu .lang-dropdown` rule, because a portalled node is no longer a
  // descendant. The direction is therefore chosen from available space below.
  useEffect(() => {
    if (!open) { setFixedPos(null); return }
    const btn = buttonRef.current
    if (!btn) return
    let el: HTMLElement | null = btn.parentElement
    let clipped = false
    while (el && el !== document.body) {
      const s = getComputedStyle(el)
      if (s.overflowX !== 'visible' || s.overflowY !== 'visible') { clipped = true; break }
      el = el.parentElement
    }
    if (!clipped) return
    const r = btn.getBoundingClientRect()
    // `min-width: 100%` on the dropdown resolves against its containing block.
    // Under `position: absolute` that was the button's wrapper; under `fixed` it
    // becomes the viewport, which stretched the list to 1031px on the first cut
    // of this fix. Carry the button's own width across explicitly.
    //
    // Direction is chosen, not assumed. The comment above used to claim the
    // mobile menu does not clip; it does — `.mobile-menu` is `overflow-y: auto`
    // — so the portal fires there too, and there the button sits in a sticky
    // footer at the bottom of the screen. Anchoring the list below it put the
    // first option at 829-857px in an 844px viewport: off the bottom edge,
    // measured, in the check added the same hour. Anchor to whichever side has
    // more room, which is what the in-place CSS was already doing with its
    // upward-opening `.mobile-menu .lang-dropdown` rule that a portal cancels.
    const below = window.innerHeight - r.bottom
    const above = r.top
    const common = { right: window.innerWidth - r.right, minWidth: r.width }
    setFixedPos(below >= above
      ? { ...common, top: r.bottom + 4 }
      : { ...common, bottom: window.innerHeight - r.top + 4 })
  }, [open])

  // Handle click outside to close
  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (buttonRef.current && !buttonRef.current.contains(e.target as Node) &&
          listRef.current && !listRef.current.contains(e.target as Node)) {
        setOpen(false)
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  // Handle escape key
  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && open) {
        setOpen(false)
        buttonRef.current?.focus()
      }
    }
    document.addEventListener('keydown', handleEscape)
    return () => document.removeEventListener('keydown', handleEscape)
  }, [open])

  const handleLangChange = (newLang: string) => {
    setLang(newLang)
    setOpen(false)
    buttonRef.current?.focus()

    // Update URL query param with new language
    const url = new URL(window.location.href)
    url.searchParams.set('lang', newLang)
    window.history.replaceState({}, '', url.toString())
  }

  const currentLangName = langNames[lang] || lang

  const dropdown = (
    <div
      ref={listRef}
      className="lang-dropdown"
      style={fixedPos ? {
        position: 'fixed', right: fixedPos.right,
        // Both offsets are always written, one of them to `auto`. The stylesheet
        // sets `top: 100%` on this class; an inline `bottom` alone leaves that in
        // force, and a fixed box with BOTH offsets set resolves its height from
        // them — 844 - 844 - 50 is negative, clamped to zero. Measured: the list
        // collapsed to 2px of border at y=848 while its options laid out at
        // 849-877, outside their own parent. Setting the unused side to `auto`
        // is what makes the chosen side mean what it says.
        top: fixedPos.top !== undefined ? fixedPos.top : 'auto',
        bottom: fixedPos.bottom !== undefined ? fixedPos.bottom : 'auto',
        minWidth: fixedPos.minWidth, width: 'max-content',
      } : undefined}
      role="listbox"
      id="lang-dropdown"
      aria-labelledby="lang-button"
      aria-activedescendant={`lang-option-${lang}`}
    >
      {LANGS.filter(l => l !== lang).map((l, index, arr) => (
        <button
          key={l}
          className="lang-option"
          onClick={() => handleLangChange(l)}
          onKeyDown={(e) => {
            if (e.key === 'Enter' || e.key === ' ') {
              e.preventDefault()
              handleLangChange(l)
            }
            if (e.key === 'Tab' && !e.shiftKey && index === arr.length - 1) {
              e.preventDefault()
              buttonRef.current?.focus()
            }
          }}
          role="option"
          aria-selected={l === lang}
          id={`lang-option-${l}`}
          type="button"
        >
          <span className="lang-flag" aria-hidden="true">{flags[l]}</span>
          <span className="lang-code">{labels[l]}</span>
          <span className="visually-hidden">{langNames[l]}</span>
        </button>
      ))}
    </div>
  )

  return (
    <div className="lang-switcher-wrap">
      <button
        ref={buttonRef}
        className="lang-switcher"
        onClick={() => setOpen(!open)}
        onKeyDown={(e) => {
          if (e.key === 'Enter' || e.key === ' ') {
            e.preventDefault()
            setOpen(!open)
          }
        }}
        aria-label={`Select language. Currently: ${currentLangName}`}
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-controls="lang-dropdown"
        id="lang-button"
        type="button"
      >
        <span className="lang-flag" aria-hidden="true">{flags[lang] || '🌐'}</span>
        <span className="lang-code">{labels[lang] || lang}</span>
        <span className="lang-arrow" aria-hidden="true">{open ? '▲' : '▼'}</span>
      </button>

      {open && (fixedPos ? createPortal(dropdown, document.body) : dropdown)}
    </div>
  )
})
