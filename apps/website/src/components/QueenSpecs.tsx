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
// The directive sits above it as one line. The full statement and the measured
// gap live on the page the frame shows.

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

export function QueenSpecs({ c }: { c: SpecsCopy }) {
  const [health, setHealth] = useState<Health | null>(null)
  const [ready, setReady] = useState(false)
  const frameRef = useRef<HTMLIFrameElement>(null)

  useEffect(() => {
    let alive = true
    fetch('t27/manifest.json')
      .then((r) => (r.ok ? r.json() : Promise.reject(new Error(String(r.status)))))
      .then((d) => { if (alive) setHealth(d.health) })
      .catch(() => {})
    return () => { alive = false }
  }, [])

  // The explorer lives at the same origin, so a relative hash URL is enough.
  const src = `${window.location.pathname}#/specs?spec=${encodeURIComponent(FEATURED)}&embed=1`

  return (
    <div className="queen27-specs">
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
