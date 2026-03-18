import { memo, useState, useRef, useEffect } from 'react'
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

      {open && (
        <div
          ref={listRef}
          className="lang-dropdown"
          role="listbox"
          id="lang-dropdown"
          aria-labelledby="lang-button"
          aria-activedescendant={`lang-option-${lang}`}
        >
          {LANGS.filter(l => l !== lang).map((l, index, arr) => (
            <button
              key={l}
              ref={index === arr.length - 1 ? (el: HTMLButtonElement) => {
                // Store ref for focus management
                if (el) {
                  (el as any).__lastOption = true
                }
              } : null}
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
      )}
    </div>
  )
})
