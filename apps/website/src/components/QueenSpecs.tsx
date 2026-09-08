// The Queen's SPECS view: the real Spec Explorer, inside the game.
//
// Not a summary of the corpus -- the working tool. Pick a spec, edit it, hit
// GO, watch every layer recompile, all without leaving the HUD.
//
// It is an iframe rather than the SpecExplorer component rendered inline.
// SpecExplorer owns a full-viewport layout (100dvh shell, its own header and
// sidebar) and mounts a 477 KB compiler wasm; dropping that into the HUD's
// grid cell would mean fighting two layout systems and instantiating the wasm
// a second time when the page already has one. Same origin, so the frame is
// not a sandbox boundary here -- it is a layout boundary, which is exactly
// what was needed.
//
// The directive used to sit above the frame, where it cost the Explorer some
// 200px of height and left the code a couple of visible lines. On a wide screen
// it now goes into the HUD's right column -- which on this view was showing the
// intel feed, i.e. another view's content -- and the frame takes the height
// back. Narrow screens have no such column, so there the directive stays put.

import { useEffect, useRef, useState } from 'react'

const FEATURED = 'specs/demos/hello_world.t27'

export interface SpecsCopy {
  directive: string
  directiveBody: string
  open: string
  loading: string
  /** Corpus counts, read from the manifest for the strip. */
  clean: string
  warnings: string
  broken: string
}

interface Health { ok: number; warn: number; fail: number }

/** The directive, its corpus counts and the way out to the full page. Rendered
 *  in the HUD's right column on a wide screen, above the frame on a narrow one. */
export function QueenSpecsDirective({ c }: { c: SpecsCopy }) {
  const [health, setHealth] = useState<Health | null>(null)

  useEffect(() => {
    let alive = true
    fetch('t27/manifest.json')
      .then((r) => (r.ok ? r.json() : Promise.reject(new Error(String(r.status)))))
      .then((d) => { if (alive) setHealth(d.health) })
      .catch(() => {})
    return () => { alive = false }
  }, [])

  return (
    <div className="queen27-specs-strip">
      <span className="queen27-section-label">{c.directive}</span>
      <p>{c.directiveBody}</p>
      {health && (
        <span className="queen27-specs-counts">
          <b style={{ color: '#00FF88' }}>{health.ok}</b> {c.clean}
          {' · '}
          <b style={{ color: '#f0a020' }}>{health.warn}</b> {c.warnings}
          {' · '}
          <b style={{ color: '#f85149' }}>{health.fail}</b> {c.broken}
        </span>
      )}
      <a
        className="queen27-specs-open"
        href={`#/specs?spec=${encodeURIComponent(FEATURED)}`}
        target="_blank"
        rel="noopener"
      >
        {c.open}
      </a>
    </div>
  )
}

export function QueenSpecs({ c, showDirective = true }: { c: SpecsCopy; showDirective?: boolean }) {
  const [ready, setReady] = useState(false)
  const frameRef = useRef<HTMLIFrameElement>(null)

  // The explorer lives at the same origin, so a relative hash URL is enough.
  const src = `${window.location.pathname}#/specs?spec=${encodeURIComponent(FEATURED)}&embed=1`

  return (
    <div className="queen27-specs" data-directive={showDirective ? 'above' : 'aside'}>
      {showDirective && <QueenSpecsDirective c={c} />}

      <div className="queen27-specs-frame-wrap">
        {!ready && <div className="queen27-specs-loading">{c.loading}</div>}
        <iframe
          ref={frameRef}
          className="queen27-specs-frame"
          src={src}
          title="Spec Explorer"
          onLoad={() => setReady(true)}
          // The explorer is ours and same-origin; it needs scripts and wasm to
          // run at all. No allow-same-origin escape concern: it is our page.
          loading="lazy"
        />
      </div>
    </div>
  )
}
