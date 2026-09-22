// BROWSER: the person's own remote browser as a view of the Queen. Decisions
// live in lib/queenBrowser.ts; this file only draws them.
import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { appSessionFromWindow } from '../lib/appSessionIdentity'
import { insidePlayer } from '../lib/triScreens'
import {
  APP_BROWSER_URL,
  STARTING_POLL_MS,
  callBroker,
  frameSrcOf,
  frameStateOf,
  journalLine,
  setWheel,
  shouldRenewWheel,
  readJournal,
  JOURNAL_POLL_MS,
  type JournalStep,
  shouldReread,
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
  journal: string
  driving: string
  handBack: string
}

const brokerEnv = {
  fetch: (url: string, init: { method: string; credentials: 'omit'; headers: Record<string, string> }) =>
    window.fetch(url, init),
  token: () => {
    const s = appSessionFromWindow()
    return s.source === 'app-session' && s.state === 'signed-in' ? s.token : null
  },
}

export function QueenBrowser({ c, embedded, lang = 'en' }: { c: BrowserCopy; embedded: boolean; lang?: 'ru' | 'en' }) {
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

  // The window says when its connection is lost (lib/queenBrowser.ts): a lost
  // connection may be a session that ended, so ask again.
  const frame = useRef<HTMLIFrameElement | null>(null)
  useEffect(() => {
    if (mode !== 'ready') return
    const onMessage = (e: MessageEvent) => {
      if (shouldReread(frameStateOf(e, frame.current?.contentWindow, window.location.origin))) void act('read')
    }
    window.addEventListener('message', onMessage)
    return () => window.removeEventListener('message', onMessage)
  }, [mode, act])

  // What the agent did in this browser (lib/queenBrowser.ts readJournal),
  // read while the window is live and the tab is on screen.
  const [journal, setJournal] = useState<JournalStep[]>([])
  const live = view?.state === 'live'
  useEffect(() => {
    if (!live) return
    let stopped = false
    const pull = async () => {
      if (document.visibilityState !== 'visible') return
      const steps = await readJournal(brokerEnv)
      if (!stopped && steps) setJournal(steps)
    }
    void pull()
    const timer = window.setInterval(() => void pull(), JOURNAL_POLL_MS)
    return () => {
      stopped = true
      window.clearInterval(timer)
    }
  }, [live])

  // The wheel (lib/queenBrowser.ts setWheel). A press inside the picture
  // does not bubble out of the frame, so the frame's own window is listened
  // to -- it is same-origin -- and attached again on every load, since the
  // window reloads itself when it reconnects.
  const [driving, setDriving] = useState(false)
  const wheelSent = useRef<number | null>(null)
  const takeTheWheel = useCallback(() => {
    setDriving(true)
    const now = Date.now()
    if (shouldRenewWheel(wheelSent.current, now)) {
      wheelSent.current = now
      void setWheel(brokerEnv, 'person')
    }
  }, [])
  const handBack = useCallback(() => {
    setDriving(false)
    wheelSent.current = null
    void setWheel(brokerEnv, 'agent')
  }, [])
  const unlisten = useRef<(() => void) | null>(null)
  const listenInside = useCallback(
    (el: HTMLIFrameElement) => {
      unlisten.current?.()
      const w = el.contentWindow
      if (!w) return
      w.addEventListener('pointerdown', takeTheWheel, true)
      w.addEventListener('keydown', takeTheWheel, true)
      unlisten.current = () => {
        w.removeEventListener('pointerdown', takeTheWheel, true)
        w.removeEventListener('keydown', takeTheWheel, true)
      }
    },
    [takeTheWheel],
  )
  useEffect(() => () => unlisten.current?.(), [])
  // After a reload or from another device: the server says who is driving.
  useEffect(() => {
    if (view?.wheel === 'person') setDriving(true)
    else if (view?.wheel === 'agent') setDriving(false)
  }, [view?.wheel])

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
          <span className="queen27-browser-hint">{driving ? c.driving : c.passwords}</span>
          {driving ? (
            <button type="button" className="queen27-browser-btn is-quiet" onClick={handBack}>
              {c.handBack}
            </button>
          ) : null}
          <button type="button" className="queen27-browser-btn is-quiet" disabled={busy} onClick={() => void act('close')}>
            {c.close}
          </button>
        </div>
        <iframe
          ref={frame}
          className="queen27-browser-frame"
          src={src}
          title={c.frameTitle}
          allow="clipboard-read; clipboard-write; fullscreen"
          onLoad={e => listenInside(e.currentTarget)}
        />
        {journal.length > 0 ? (
          <ol className="queen27-browser-journal" aria-label={c.journal}>
            {journal.map((step, i) => {
              const line = journalLine(step, lang)
              return (
                <li key={`${step.at}:${i}`} className={line.ok ? '' : 'is-error'}>
                  <time>{line.time}</time> <b>{line.verb}</b> <span>{line.text}</span>
                </li>
              )
            })}
          </ol>
        ) : null}
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
