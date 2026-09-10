// The one place the site asks "what kind of viewport is this".
//
// The tiers and their bounds come from specs/ui/viewport.t27 through
// src/lib/viewport.generated.ts; nothing here types a pixel value. Pages read
// `tier` for the shape of their layout and `coarsePointer` for touch-sized
// controls; `width` and `height` are there for the few places that need the
// number itself (the header's chrome trimming).
import { useEffect, useState } from 'react'
import { COARSE_POINTER_QUERY, TIERS_ORDER, tierOf, tierQuery, type ViewportTier } from './viewport.generated'

export interface Viewport {
  tier: ViewportTier
  width: number
  height: number
  /** The primary pointer cannot hover: a touch screen. */
  coarsePointer: boolean
}

function read(): Viewport {
  if (typeof window === 'undefined') return { tier: 'desktop', width: 0, height: 0, coarsePointer: false }
  return {
    tier: tierOf(window.innerWidth),
    width: window.innerWidth,
    height: window.innerHeight,
    coarsePointer: window.matchMedia(COARSE_POINTER_QUERY).matches,
  }
}

const same = (a: Viewport, b: Viewport) => a.tier === b.tier && a.width === b.width && a.height === b.height && a.coarsePointer === b.coarsePointer

export function useViewport(): Viewport {
  const [vp, setVp] = useState<Viewport>(read)
  useEffect(() => {
    const sync = () => setVp((prev) => { const next = read(); return same(prev, next) ? prev : next })
    // One matchMedia per tier boundary plus the pointer query, and `resize` as
    // well as `change`: a programmatic viewport change does not always deliver
    // a matchMedia change event -- it did not in the headless browser the
    // SpecExplorer's phone mode was verified in, which read as the layout
    // being stuck until the page was reloaded. Every listener calls the same
    // setter, and the setter keeps the previous object when nothing changed,
    // so double-firing is a no-op.
    const queries = [...TIERS_ORDER.map((t) => window.matchMedia(tierQuery(t))), window.matchMedia(COARSE_POINTER_QUERY)]
    for (const q of queries) q.addEventListener('change', sync)
    window.addEventListener('resize', sync)
    sync()
    return () => {
      for (const q of queries) q.removeEventListener('change', sync)
      window.removeEventListener('resize', sync)
    }
  }, [])
  return vp
}

/**
 * Locks the document while a page is a full-height shell: the phone and
 * tablet explorers own their scrolling (one scroller per pane, spec
 * DOCUMENT_SCROLLS = false), so body must not add a scroller of its own.
 * index.css gives body an 80px bottom padding for the long pages; measured
 * before this, a 390x844 phone had document scrollHeight 924 under a 100dvh
 * explorer, and the extra 80px were that padding. The class is scoped in
 * src/styles/explorer-viewport.css and removed on unmount, so the long pages
 * are untouched. Not applied on desktop and wide: those tiers are frozen by
 * the P0 brief (pixel-identical at 1280), and the desktop document scroll is
 * recorded as a P1 finding instead.
 */
export function useDocumentLock(active: boolean) {
  useEffect(() => {
    if (!active) return
    document.body.classList.add('explorer-shell')
    return () => document.body.classList.remove('explorer-shell')
  }, [active])
}
