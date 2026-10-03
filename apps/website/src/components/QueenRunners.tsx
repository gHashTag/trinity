// MY RUNNERS: mint, list and revoke the runner tokens of the person signed in
// on app.t27.ai. Decisions live in lib/queenRunners.ts; this file only draws
// them. There is no field for a provider key here and there never will be: the
// key stays on the runner's machine, which is the whole reason a runner exists.
import { useCallback, useEffect, useState } from 'react'
import { appSessionFromWindow } from '../lib/appSessionIdentity'
import { QUEEN_API } from '../lib/queenApi'
import {
  CABINET_HOME,
  type CabinetView,
  callRunners,
  type RunnersCall,
  type RunnersEnv,
  setupLines,
} from '../lib/queenRunners'
import { RUNNERS_COPY } from '../lib/queenRunnersCopy'
import './QueenRunners.css'

const env: RunnersEnv = {
  base: QUEEN_API,
  fetch: (url, init) => window.fetch(url, init),
  token: () => {
    const s = appSessionFromWindow()
    return s.source === 'app-session' && s.state === 'signed-in' ? s.token : null
  },
}

export default function QueenRunners({ lang }: { lang: 'en' | 'ru' }) {
  const c = RUNNERS_COPY[lang]
  const session = appSessionFromWindow()
  const [view, setView] = useState<CabinetView | null>(null)
  const [busy, setBusy] = useState(false)
  const [label, setLabel] = useState('')
  const [copied, setCopied] = useState(false)

  const cabinet = view && 'cabinet' in view ? view.cabinet : undefined

  const act = useCallback(
    async (call: RunnersCall) => {
      setBusy(true)
      try {
        const next = await callRunners(env, call, cabinet)
        setView(next)
        if (next.state === 'minted') setLabel('')
      } catch {
        setView({ state: 'unavailable' })
      } finally {
        setBusy(false)
      }
    },
    [cabinet],
  )

  useEffect(() => {
    if (session.source === 'app-session') void act({ kind: 'list' })
    // Once per mount: the list is re-read after every action anyway.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const head = (
    <header className="qr-head">
      <h3>{c.title}</h3>
      <p>{c.lead}</p>
      <p className="qr-key">{c.keyStays}</p>
    </header>
  )

  // On t27.ai the session is not in reach, and the bridge's game token is not
  // this panel's to forward. Say where the cabinet is instead.
  if (session.source === 'bridge') {
    return (
      <section className="qr">
        {head}
        <p className="qr-note">
          {c.elsewhere}{' '}
          <a href={CABINET_HOME} target="_blank" rel="noreferrer noopener">
            app.t27.ai/queen
          </a>
        </p>
      </section>
    )
  }

  if (session.state === 'signed-out' || view?.state === 'signin') {
    return (
      <section className="qr">
        {head}
        <p className="qr-note">{c.signin}</p>
      </section>
    )
  }

  return (
    <section className="qr">
      {head}
      {view === null && <p className="qr-note">{c.loading}</p>}
      {view?.state === 'unavailable' && (
        <p className="qr-note" role="alert">
          {c.unavailable}
        </p>
      )}

      {view?.state === 'minted' && (
        <div className="qr-minted" role="status">
          <b>
            {c.mintedTitle}: {view.runner.label}
          </b>
          <p>{c.mintedOnce}</p>
          <pre className="qr-setup">{setupLines(view.token, QUEEN_API).join('\n')}</pre>
          <div className="qr-actions">
            <button
              type="button"
              onClick={() => {
                void navigator.clipboard
                  ?.writeText(view.token)
                  .then(() => setCopied(true))
                  .catch(() => setCopied(false))
              }}
            >
              {copied ? c.copied : c.copy}
            </button>
            <button
              type="button"
              onClick={() => {
                setCopied(false)
                setView({ state: 'ready', cabinet: view.cabinet })
              }}
            >
              {c.done}
            </button>
          </div>
        </div>
      )}

      {cabinet && (
        <>
          {cabinet.runners.length === 0 ? (
            <p className="qr-note">{c.none}</p>
          ) : (
            <ul className="qr-list">
              {cabinet.runners.map((r) => (
                <li key={r.id} className={`qr-row is-${r.state}`}>
                  <span className="qr-dot" aria-hidden="true" />
                  <span className="qr-label">{r.label}</span>
                  <span className="qr-meta">
                    {c.state[r.state]} · {c.lane} #{r.lane} · …{r.tokenHint}
                  </span>
                  <button
                    type="button"
                    disabled={busy}
                    onClick={() => {
                      if (window.confirm(c.revokeConfirm(r.label))) void act({ kind: 'revoke', id: r.id })
                    }}
                  >
                    {c.revoke}
                  </button>
                </li>
              ))}
            </ul>
          )}
          <form
            className="qr-form"
            onSubmit={(e) => {
              e.preventDefault()
              if (busy) return
              void act({ kind: 'create', label })
            }}
          >
            <input
              value={label}
              maxLength={40}
              placeholder={c.namePlaceholder}
              aria-label={c.namePlaceholder}
              onChange={(e) => setLabel(e.target.value)}
              disabled={busy || cabinet.runners.length >= cabinet.limit}
            />
            <button type="submit" disabled={busy || cabinet.runners.length >= cabinet.limit}>
              {c.create}
            </button>
          </form>
          <p className="qr-small">
            {view?.state === 'refused' && view.reason === 'label' ? c.refusedLabel : c.limit(cabinet.limit)}
          </p>
        </>
      )}
      <p className="qr-small">{c.nextStage}</p>
    </section>
  )
}
