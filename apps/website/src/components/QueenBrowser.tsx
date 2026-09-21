// BROWSER: the person's own remote browser as a view of the Queen. Decisions
// live in lib/queenBrowser.ts; this file only draws them.
import { useCallback, useEffect, useMemo, useState } from 'react'
import { appSessionFromWindow } from '../lib/appSessionIdentity'
import { insidePlayer } from '../lib/triScreens'
import {
  APP_BROWSER_URL,
  STARTING_POLL_MS,
  callBroker,
  frameSrcOf,
  panelMode,
  type BrokerCall,
  type BrowserView,
} from '../lib/queenBrowser'
import './QueenBrowser.css'

export interface BrowserCopy {
  preview: string
  nested: string
  signin: string
  openInApp: string
  none: string
  open: string
  starting: string
  unavailable: string
  close: string
  failed: string
  retry: string
  frameTitle: string
  passwords: string
}

const brokerEnv = {
  fetch: (url: string, init: { method: string; credentials: 'omit'; headers: Record<string, string> }) =>
    window.fetch(url, init),
  token: () => {
    const s = appSessionFromWindow()
    return s.source === 'app-session' && s.state === 'signed-in' ? s.token : null
  },
}

export function QueenBrowser({ c, embedded }: { c: BrowserCopy; embedded: boolean }) {
  const nested = useMemo(
    () =>
      insidePlayer({
        isTop: window.self === window.top,
        ancestorOrigins: window.location.ancestorOrigins ? [...window.location.ancestorOrigins] : undefined,
        referrer: document.referrer,
        ownOrigin: window.location.origin,
      }),
    [],
  )
  const mode = panelMode({ embedded, nested, session: appSessionFromWindow() })

  const [view, setView] = useState<BrowserView | null>(null)
  const [busy, setBusy] = useState(false)
  const [failed, setFailed] = useState(false)

  const act = useCallback(async (call: BrokerCall) => {
    setBusy(true)
    setFailed(false)
    try {
      setView(await callBroker(brokerEnv, call))
    } catch {
      setFailed(true)
    } finally {
      setBusy(false)
    }
  }, [])

  // Read on arrival -- never open. Opening wakes a pod; only a press does that.
  useEffect(() => {
    if (mode === 'ready') void act('read')
  }, [mode, act])

  // A pod that is still starting is asked again until it answers otherwise.
  useEffect(() => {
    if (view?.state !== 'starting') return
    const timer = window.setTimeout(() => void act('read'), STARTING_POLL_MS)
    return () => window.clearTimeout(timer)
  }, [view, act])

  if (mode === 'preview') {
    return (
      <div className="queen27-browser is-note">
        <p>{c.preview}</p>
      </div>
    )
  }

  if (mode === 'nested') {
    return (
      <div className="queen27-browser is-note">
        <p>{c.nested}</p>
        <a className="queen27-browser-btn" href={APP_BROWSER_URL} target="_top" rel="noopener">
          {c.openInApp}
        </a>
      </div>
    )
  }

  const state = view?.state
  if (mode === 'signin' || state === 'signin') {
    return (
      <div className="queen27-browser is-note">
        <p>{c.signin}</p>
        <a className="queen27-browser-btn" href={APP_BROWSER_URL} target="_top" rel="noopener">
          {c.openInApp}
        </a>
      </div>
    )
  }

  if (failed) {
    return (
      <div className="queen27-browser is-note">
        <p>{c.failed}</p>
        <button type="button" className="queen27-browser-btn" disabled={busy} onClick={() => void act('read')}>
          {c.retry}
        </button>
      </div>
    )
  }

  if (state === 'unavailable') {
    return (
      <div className="queen27-browser is-note">
        <p>{c.unavailable}</p>
      </div>
    )
  }

  const src = state === 'live' ? frameSrcOf(view?.viewUrl, window.location.origin) : null

  if (state === 'live' && src) {
    return (
      <div className="queen27-browser is-live">
        <div className="queen27-browser-bar">
          <span className="queen27-browser-hint">{c.passwords}</span>
          <button type="button" className="queen27-browser-btn is-quiet" disabled={busy} onClick={() => void act('close')}>
            {c.close}
          </button>
        </div>
        <iframe
          className="queen27-browser-frame"
          src={src}
          title={c.frameTitle}
          allow="clipboard-read; clipboard-write; fullscreen"
        />
      </div>
    )
  }

  // none, starting, a live answer we will not frame, or still reading.
  const starting = state === 'starting' || (busy && state !== undefined)
  return (
    <div className="queen27-browser is-note">
      <p>{starting ? c.starting : c.none}</p>
      <button type="button" className="queen27-browser-btn" disabled={busy || state === undefined} onClick={() => void act('open')}>
        {c.open}
      </button>
      {state === 'live' && !src ? (
        <a className="queen27-browser-link" href={APP_BROWSER_URL} target="_top" rel="noopener">
          {c.openInApp}
        </a>
      ) : null}
    </div>
  )
}
