import { Suspense, lazy, useRef, useState } from 'react'
import { useI18n } from '../i18n/context'
import { MODULES } from '../lib/queenModules'
import type { UniverseAtlas } from '../lib/queenUniverseAtlas'
import { useCorpus } from '../lib/queenCorpus'
import { webglAvailable } from '../lib/webgl'
import { SceneBoundary } from './SceneBoundary'
import PlayLine from './PlayLine'
import type { CombHandle } from './queenHud'
import './QueenHeroBlock.css'

// The same component the /queen route mounts, not a copy of it: the hive is a
// one-screen module, and the homepage shows that module rather than a picture of
// it. Lazy, so the landing paints before Babylon arrives, and only ever one
// instance is mounted because the homepage and /queen are different routes.
const QueenCatalogHive = lazy(() => import('./QueenCatalogHive').then((m) => ({ default: m.QueenCatalogHive })))

const copy = {
  en: {
    eyebrow: 'QUEEN / .t27',
    title: 'The goal of the game is a .t27 spec',
    body: 'Every gold cell on the map is a .t27 source; every red one is the GitHub issue that pays for it. Open the map to see where a spec lives and what it is linked to, or read the corpus itself in the Spec Explorer.',
    map: 'Open the map',
    core: 'Shared core',
    loading: 'Loading public atlas',
    unavailable: 'Public atlas unavailable',
    repositories: 'repositories',
    issues: 'issues',
    specsCount: '.t27 sources',
    snapshot: 'public snapshot',
  },
  ru: {
    eyebrow: 'QUEEN / .t27',
    title: 'Цель игры — спека .t27',
    body: 'Каждая золотая сота на карте — источник .t27, каждая красная — GitHub issue, которая за неё платит. Откройте карту, чтобы увидеть, где живёт спека и с чем она связана, или прочитайте сам корпус в Обозревателе спек.',
    map: 'Открыть карту',
    core: 'Общее ядро',
    loading: 'Загружаю публичный атлас',
    unavailable: 'Публичный атлас недоступен',
    repositories: 'репозиториев',
    issues: 'issues',
    specsCount: 'источников .t27',
    snapshot: 'публичный снимок',
  },
} as const

export default function QueenHeroBlock() {
  const { lang: rawLang } = useI18n()
  const lang = rawLang === 'ru' ? 'ru' : 'en'
  const t = copy[lang]
  // The atlas the comb draws, from the corpus store the Queen reads (lib/queenCorpus).
  const atlas: UniverseAtlas | null = useCorpus('atlas').part?.data ?? null
  const comb = useRef<CombHandle>(null)
  // Whether the live scene is drawn here at all. Without WebGL the chunk is not
  // even fetched: the block's words, its links and the counts below are the
  // content, and they stand on a dark frame instead of a lattice. A scene that
  // throws anyway (a context refused after the probe, a build that fails) is
  // caught by the boundary and leaves the same frame, never a blank page --
  // which is what one uncaught throw here made of the whole landing on
  // 2026-10-03 (lib/webgl.ts).
  const [scene, setScene] = useState<'webgl' | 'none' | 'failed'>(() => (webglAvailable() ? 'webgl' : 'none'))

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
          {/* The move itself comes from the module record, not from the copy
              above: this block writes its own description because it mounts the
              live scene, but what the comb is FOR is one sentence and belongs in
              one place. */}
          <PlayLine>{MODULES.find((module) => module.tab === 'comb')![lang].play}</PlayLine>
          <div className="queen-hero-block-actions">
            <a className="queen-hero-block-primary" href="#/queen">{t.map}</a>
            <a className="queen-hero-block-secondary" href="#/queen?view=core">{t.core}</a>
          </div>
        </div>
        <div className="queen-hero-block-atlas" aria-label={atlas ? t.snapshot : t.loading} data-scene={scene}>
          {atlas && scene === 'webgl' && (
            <SceneBoundary lang={lang} fallback={null} onError={() => setScene('failed')}>
              <Suspense fallback={null}>
                <QueenCatalogHive atlas={atlas} lang={lang} handleRef={comb} foundationVisible fitInset={0} />
              </Suspense>
            </SceneBoundary>
          )}
          <div className="queen-hero-block-stats">
            <strong>{atlas ? specs : '—'}</strong><span>{t.specsCount}</span>
            <strong>{atlas ? issues : '—'}</strong><span>{t.issues}</span>
            <strong>{atlas ? repositories : '—'}</strong><span>{t.repositories}</span>
          </div>
          <small>{atlas ? `${t.snapshot} · ${new Date(atlas.at).toLocaleDateString(lang)}` : t.unavailable}</small>
        </div>
      </div>
    </section>
  )
}
