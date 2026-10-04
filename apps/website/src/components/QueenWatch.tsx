// INVITE TO WATCH, on the BROWSER view's live bar. Decisions live in
// lib/queenWatch.ts; this file only draws them. The minted address lives in
// this component's state and nowhere else: closing the panel forgets it.
import { useCallback, useEffect, useState } from 'react'
import {
  WATCH_DEFAULT_HOURS,
  WATCH_HOURS_CHOICES,
  WATCH_LABEL_MAX,
  WATCH_POLL_MS,
  canMint,
  createWatchLink,
  listWatchLinks,
  liveLinks,
  revokeWatchLink,
  shouldPollWatch,
  timeLeft,
  watchingNow,
  type MintedLink,
  type WatchEnv,
  type WatchLink,
  type WatchRefusal,
} from '../lib/queenWatch'

export interface WatchCopy {
  invite: string
  note: string
  forHours: string
  hour: string
  label: string
  create: string
  once: string
  copy: string
  copied: string
  revoke: string
  watching: string
  views: string
  none: string
  full: string
  failed: string
  hide: string
}

export function QueenWatch({ c, lang, env }: { c: WatchCopy; lang: 'ru' | 'en'; env: WatchEnv }) {
  const [open, setOpen] = useState(false)
  const [links, setLinks] = useState<WatchLink[]>([])
  const [now, setNow] = useState(() => Date.now())
  const [minted, setMinted] = useState<MintedLink | null>(null)
  const [hours, setHours] = useState(WATCH_DEFAULT_HOURS)
  const [label, setLabel] = useState('')
  const [busy, setBusy] = useState(false)
  const [why, setWhy] = useState<WatchRefusal | null>(null)
  const [copied, setCopied] = useState(false)

  const reload = useCallback(async () => {
    const r = await listWatchLinks(env)
    setNow(Date.now())
    if (r.ok) setLinks(r.value)
  }, [env])

  // Read once with the live window, on screen or not: the count on the button
  // needs it even with the panel shut. (First shipped gated on visibility: a
  // board opened in a background tab skipped that one read, found nothing
  // live, so never polled -- and showed no audience until the panel was
  // pressed. Seen in a harness, 2026-10-04.) After that, re-read while the
  // panel is open or something is live, only on screen, and once more
  // whenever the tab comes back.
  const poll = open || shouldPollWatch(links, now)
  useEffect(() => {
    let stopped = false
    const pull = async (always: boolean) => {
      if (!always && document.visibilityState !== 'visible') return
      const r = await listWatchLinks(env)
      if (stopped || !r.ok) return
      setLinks(r.value)
      setNow(Date.now())
    }
    void pull(true)
    const onShow = () => void pull(false)
    document.addEventListener('visibilitychange', onShow)
    const timer = poll ? window.setInterval(() => void pull(false), WATCH_POLL_MS) : null
    return () => {
      stopped = true
      document.removeEventListener('visibilitychange', onShow)
      if (timer !== null) window.clearInterval(timer)
    }
  }, [poll, env])

  const shut = () => {
    setOpen(false)
    setMinted(null)
    setCopied(false)
    setWhy(null)
  }

  const mint = async () => {
    setBusy(true)
    setWhy(null)
    setCopied(false)
    const r = await createWatchLink(env, { hours, label })
    setBusy(false)
    if (r.ok) {
      setMinted(r.value)
      setLabel('')
    } else setWhy(r.why)
    void reload()
  }

  const revoke = async (id: string) => {
    setBusy(true)
    const r = await revokeWatchLink(env, id)
    setBusy(false)
    if (!r.ok && r.why !== 'gone') setWhy(r.why)
    if (minted?.id === id) setMinted(null)
    void reload()
  }

  const copy = async () => {
    if (!minted) return
    try {
      await navigator.clipboard.writeText(minted.url)
      setCopied(true)
    } catch {
      // No clipboard (an older WebView): the field is selectable, say nothing.
    }
  }

  const live = liveLinks(links, now)
  const watching = watchingNow(links, now)
  const room = canMint(links, now)
  const message = !room || why === 'full' ? c.full : why ? c.failed : null

  return (
    <div className="queen27-watch">
      <button
        type="button"
        className={`queen27-browser-btn is-quiet${watching > 0 ? ' is-watched' : ''}`}
        aria-expanded={open}
        onClick={() => (open ? shut() : setOpen(true))}
      >
        {watching > 0 ? `${c.invite} · ${watching} ${c.watching}` : c.invite}
      </button>
      {open ? (
        <div className="queen27-watch-panel" role="dialog" aria-label={c.invite}>
          <p>{c.note}</p>
          {minted ? (
            <div className="queen27-watch-minted">
              <input readOnly value={minted.url} onFocus={e => e.currentTarget.select()} aria-label={c.invite} />
              <button type="button" className="queen27-browser-btn" onClick={() => void copy()}>
                {copied ? c.copied : c.copy}
              </button>
              <p>{c.once}</p>
            </div>
          ) : null}
          <div className="queen27-watch-form">
            <label>
              {c.forHours}{' '}
              <select value={hours} onChange={e => setHours(Number(e.currentTarget.value))}>
                {WATCH_HOURS_CHOICES.map(h => (
                  <option key={h} value={h}>
                    {h} {c.hour}
                  </option>
                ))}
              </select>
            </label>
            <input
              value={label}
              maxLength={WATCH_LABEL_MAX}
              placeholder={c.label}
              aria-label={c.label}
              onChange={e => setLabel(e.currentTarget.value)}
            />
            <button
              type="button"
              className="queen27-browser-btn"
              disabled={busy || !room}
              onClick={() => void mint()}
            >
              {c.create}
            </button>
          </div>
          {message ? <p className="queen27-watch-error">{message}</p> : null}
          {live.length === 0 ? (
            <p>{c.none}</p>
          ) : (
            <ul className="queen27-watch-list">
              {live.map(l => (
                <li key={l.id}>
                  <span>
                    <b>{l.label ?? l.id}</b> · {timeLeft(l.expiresAt, now, lang)} · {l.views} {c.views}
                    {l.watchingNow > 0 ? ` · ${l.watchingNow} ${c.watching}` : ''}
                  </span>
                  <button type="button" className="queen27-browser-btn is-quiet" disabled={busy} onClick={() => void revoke(l.id)}>
                    {c.revoke}
                  </button>
                </li>
              ))}
            </ul>
          )}
          <button type="button" className="queen27-browser-btn is-quiet" onClick={shut}>
            {c.hide}
          </button>
        </div>
      ) : null}
    </div>
  )
}
