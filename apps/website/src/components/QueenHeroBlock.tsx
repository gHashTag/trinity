import { useEffect, useState } from 'react'
import { useI18n } from '../i18n/context'
import { validateAtlas, type UniverseAtlas } from '../lib/queenUniverseAtlas'
import './QueenHeroBlock.css'

const copy = {
  en: {
    eyebrow: 'QUEEN / SHARED CORE',
    title: 'One map for repositories, issues and .t27 sources',
    body: 'Follow the public repository worlds, inspect GitHub issues and trace shared specifications without leaving the game.',
    map: 'Open Queen map',
    specs: 'Open Specs',
    loading: 'Loading public atlas',
    unavailable: 'Public atlas unavailable',
    repositories: 'repositories',
    issues: 'issues',
    specsCount: '.t27 sources',
    snapshot: 'public snapshot',
  },
  ru: {
    eyebrow: 'QUEEN / ОБЩЕЕ ЯДРО',
    title: 'Одна карта для репозиториев, issues и .t27-источников',
    body: 'Смотрите публичные миры репозиториев, GitHub issues и связанные спеки, не выходя из игры.',
    map: 'Открыть карту Queen',
    specs: 'Открыть Specs',
    loading: 'Загружаю публичный атлас',
    unavailable: 'Публичный атлас недоступен',
    repositories: 'репозиториев',
    issues: 'issues',
    specsCount: '.t27-источников',
    snapshot: 'публичный снимок',
  },
} as const

export default function QueenHeroBlock() {
  const { lang: rawLang } = useI18n()
  const lang = rawLang === 'ru' ? 'ru' : 'en'
  const t = copy[lang]
  const [atlas, setAtlas] = useState<UniverseAtlas | null>(null)

  useEffect(() => {
    const controller = new AbortController()
    fetch('t27/universe-atlas.json', { signal: controller.signal, credentials: 'omit' })
      .then((response) => response.ok ? response.json() : Promise.reject(new Error('atlas')))
      .then((value) => setAtlas(validateAtlas(value)))
      .catch(() => { if (!controller.signal.aborted) setAtlas(null) })
    return () => controller.abort()
  }, [])

  const repositories = atlas?.worlds.filter((world) => world.specCount > 0).length ?? 0
  const issues = atlas?.issues.length ?? 0
  const specs = atlas?.specs.length ?? 0

  return (
    <section className="queen-hero-block" aria-labelledby="queen-hero-title">
      <div className="queen-hero-block-inner">
        <div className="queen-hero-block-copy">
          <span className="queen-hero-block-eyebrow">{t.eyebrow}</span>
          <h2 id="queen-hero-title">{t.title}</h2>
          <p>{t.body}</p>
          <div className="queen-hero-block-actions">
            <a className="queen-hero-block-primary" href="#/queen">{t.map}</a>
            <a className="queen-hero-block-secondary" href="#/queen?view=core">{t.specs}</a>
          </div>
        </div>
        <div className="queen-hero-block-atlas" aria-label={atlas ? t.snapshot : t.loading}>
          <div className="queen-hero-block-cell queen-hero-block-cell-core" aria-hidden="true" />
          <div className="queen-hero-block-cell queen-hero-block-cell-repo queen-hero-block-cell-a" aria-hidden="true" />
          <div className="queen-hero-block-cell queen-hero-block-cell-repo queen-hero-block-cell-b" aria-hidden="true" />
          <div className="queen-hero-block-stats">
            <strong>{atlas ? repositories : '—'}</strong><span>{t.repositories}</span>
            <strong>{atlas ? issues : '—'}</strong><span>{t.issues}</span>
            <strong>{atlas ? specs : '—'}</strong><span>{t.specsCount}</span>
          </div>
          <small>{atlas ? `${t.snapshot} · ${new Date(atlas.at).toLocaleDateString(lang)}` : t.unavailable}</small>
        </div>
      </div>
    </section>
  )
}
