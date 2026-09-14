// The Queen's TRI view: the app at app.t27.ai inside the game.
//
// A row of the app's screens (feed, agent, AI, profile, CRM) over one frame of
// the real app page, https://app.t27.ai/<route>?embed=1&lang=<lang>. The app
// in embed mode hides its own header and tab bar, so this row is its navigation.
//
// Every screen has its own address, like every tab: ?tab=tri&screen=chat, and
// path= for one profile (the CRM is addressed at its list, never by client id).
// A click writes it, a reload reads it, and an address changed from outside
// (Back, a link, a script) moves the screen. Stages the app switches inside the
// frame (the AI pipeline, a profile) come back as a {type:'t27-app', kind:'route',
// path} message and are written to the address without reloading the frame.
//
// Nothing is ever posted INTO the frame: telegram-web-app.js in the app treats
// JSON messages from its parent as Telegram events (and reloads on one of them).

import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { QueenLoading } from './QueenLoading'
import {
  TRI_BUTTONS,
  acceptAppMessage,
  appScreenUrl,
  hashParamsOf,
  insidePlayer,
  screenOfAppPath,
  triAddress,
  triFrameSrc,
  triGroupOf,
  triPathOf,
  triScreenOf,
  type TriGroup,
  type TriScreen,
} from '../lib/triScreens'
import './QueenTri.css'

export interface TriCopy {
  screens: string
  feed: string
  agent: string
  ai: string
  profile: string
  crm: string
  loading: string
  noAnswer: string
  openApp: string
  frameTitle: string
  insidePlayer: string
  preview: string
}

/** Without an answer from the app this long after the frame loaded, say so. */
export const TRI_ANSWER_MS = 8000

const labelOf = (c: TriCopy, group: TriGroup): string =>
  group === 'feed' ? c.feed : group === 'chat' ? c.agent : group === 'ai' ? c.ai : group === 'profile' ? c.profile : c.crm

const keyOf = (screen: TriScreen, path: string | null) => `${screen}|${path ?? ''}`

interface Frame {
  screen: TriScreen
  path: string | null
  lang: string
  nonce: number
}

export function QueenTri({ c, lang, embedded }: { c: TriCopy; lang: string; embedded: boolean }) {
  const [hashParams, setHashParams] = useSearchParams()
  const addressScreen = triScreenOf(hashParams.get('screen'))
  const addressPath = triPathOf(addressScreen, hashParams.get('path'))
  const addressKey = keyOf(addressScreen, addressPath)

  // What the row shows and the address says. The frame is separate: a route
  // message from the app moves the screen but must not reload the frame.
  const [screen, setScreen] = useState<TriScreen>(addressScreen)
  const [path, setPath] = useState<string | null>(addressPath)
  const [frame, setFrame] = useState<Frame>({ screen: addressScreen, path: addressPath, lang, nonce: 0 })

  // An address changed from outside moves the screen. Only the address is
  // tracked here: this component's own writes wait in the router's transition
  // (seconds on t27.ai while the hive runs), and an address that lags the live
  // hash is one of those, not an outside change -- acting on it would move the
  // screen back and reload the frame on the old root.
  const [seenAddress, setSeenAddress] = useState(addressKey)
  if (seenAddress !== addressKey) {
    setSeenAddress(addressKey)
    const live = hashParamsOf(window.location.hash)
    const liveScreen = triScreenOf(live.get('screen'))
    const liveKey = keyOf(liveScreen, triPathOf(liveScreen, live.get('path')))
    if (liveKey === addressKey && addressKey !== keyOf(screen, path)) {
      setScreen(addressScreen)
      setPath(addressPath)
      setFrame((f) => ({ screen: addressScreen, path: addressPath, lang, nonce: f.nonce + 1 }))
    }
  }

  // The language of the game is the language of the frame.
  if (frame.lang !== lang) {
    setFrame((f) => ({ ...f, screen, path, lang, nonce: f.nonce + 1 }))
  }

  // Built from the live hash, not from the params of the last render: the
  // shell's tab write and this one may both be pending, and each keeps the other's key.
  const writeAddress = useCallback(
    (next: TriScreen, nextPath: string | null) => {
      setHashParams(() => triAddress(window.location.hash, next, nextPath), { replace: true })
    },
    [setHashParams],
  )

  const choose = (next: TriScreen) => {
    // Any click opens the screen at its root, so after moving to another
    // person's profile a click on Profile returns to the viewer's own.
    setScreen(next)
    setPath(null)
    setFrame((f) => ({ screen: next, path: null, lang, nonce: f.nonce + 1 }))
    writeAddress(next, null)
  }

  const frameRef = useRef<HTMLIFrameElement>(null)
  const [loadedNonce, setLoadedNonce] = useState(-1)
  const [answeredNonce, setAnsweredNonce] = useState(-1)
  const [silentNonce, setSilentNonce] = useState(-1)

  useEffect(() => {
    const onMessage = (event: MessageEvent) => {
      const message = acceptAppMessage(event, frameRef.current?.contentWindow ?? null)
      if (!message) return
      setAnsweredNonce(frame.nonce)
      const next = screenOfAppPath(message.path)
      if (!next) return
      const nextPath = triPathOf(next, message.path)
      if (next === screen && nextPath === path) return
      setScreen(next)
      setPath(nextPath)
      writeAddress(next, nextPath)
    }
    window.addEventListener('message', onMessage)
    return () => window.removeEventListener('message', onMessage)
  }, [frame.nonce, screen, path, writeAddress])

  // One frame element for the life of the view. Its src attribute stays the
  // first URL: changing it would PUSH a history entry for every screen. A new
  // screen instead replaces the frame's current entry, so screen clicks add
  // nothing to Back. Pages the app pushes inside the frame do add entries (a
  // fresh element per screen would strand them: Back would do nothing until
  // they ran out). With one element, Back walks them, the app's route message
  // moves screen= along, and the frame and the address stay in step.
  const src = triFrameSrc(frame.screen, frame.lang, frame.path)
  const [mountSrc] = useState(src)
  const navigatedNonce = useRef(frame.nonce)
  useEffect(() => {
    if (navigatedNonce.current === frame.nonce) return
    navigatedNonce.current = frame.nonce
    frameRef.current?.contentWindow?.location.replace(src)
  }, [frame.nonce, src])

  // A frame the app refuses (frame-ancestors) still fires load on Chrome's
  // error page, so load is not success: the app's own message is.
  useEffect(() => {
    if (loadedNonce !== frame.nonce) return
    const timer = window.setTimeout(() => setSilentNonce(frame.nonce), TRI_ANSWER_MS)
    return () => window.clearTimeout(timer)
  }, [loadedNonce, frame.nonce])

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

  const group = triGroupOf(screen)

  if (nested) {
    return (
      <div className="queen27-tri is-nested">
        <p className="queen27-tri-nested">{c.insidePlayer}</p>
        <ul className="queen27-tri-nested-list" aria-label={c.screens}>
          {TRI_BUTTONS.map((button) => (
            <li key={button}>{labelOf(c, triGroupOf(button))}</li>
          ))}
        </ul>
      </div>
    )
  }

  // A preview of another module on the landing (embed=1) reaches TRI by a key
  // press. It frames nothing: the app would load for a visitor who never asked,
  // inside a sandbox where the link out cannot open.
  if (embedded) {
    return (
      <div className="queen27-tri is-preview">
        <p className="queen27-tri-nested">{c.preview}</p>
      </div>
    )
  }

  const outside = appScreenUrl(screen, path)
  const answered = answeredNonce === frame.nonce
  const loading = loadedNonce !== frame.nonce && !answered
  const silent = silentNonce === frame.nonce && !answered

  return (
    <div className="queen27-tri" data-screen={screen}>
      <div className="queen27-tri-screens" role="group" aria-label={c.screens}>
        {TRI_BUTTONS.map((button) => {
          const buttonGroup = triGroupOf(button)
          const active = buttonGroup === group
          return (
            <button
              type="button"
              key={button}
              className={`queen27-tri-screen${active ? ' is-active' : ''}`}
              data-screen={button}
              aria-pressed={active}
              onClick={() => choose(button)}
            >
              {labelOf(c, buttonGroup)}
            </button>
          )
        })}
      </div>

      {silent && (
        <div className="queen27-tri-noanswer" role="status">
          <span>{c.noAnswer}</span>
          <a href={outside} target="_blank" rel="noopener">
            {c.openApp}
          </a>
        </div>
      )}

      <div className="queen27-tri-frame-wrap">
        {loading && (
          <div className="queen27-tri-loading">
            <QueenLoading title={c.loading} facts={[outside]} />
          </div>
        )}
        {/* src is the first URL only; data-src names the page the frame was last sent to. */}
        <iframe
          ref={frameRef}
          className="queen27-tri-frame"
          src={mountSrc}
          data-src={src}
          title={`${c.frameTitle} - ${labelOf(c, triGroupOf(frame.screen))}`}
          allow="clipboard-write; fullscreen"
          referrerPolicy="strict-origin-when-cross-origin"
          onLoad={() => setLoadedNonce(frame.nonce)}
        />
      </div>
    </div>
  )
}
