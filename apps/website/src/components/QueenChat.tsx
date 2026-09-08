import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import ChatInput from './chat/ChatInput'
import ChatMessage from './chat/ChatMessage'
import type { ChatResponse } from '../services/chatApi'
import { askQueen, queenHealth, queenModelName } from '../services/queenModel'
import type { HudEvent } from './queenHud'
import './QueenChat.css'

export interface QueenChatContext {
  view: string
  spec?: string | null
  repo?: string | null
}

type Turn = { kind: 'turn'; at: number; role: 'user' | 'assistant'; content: string } & Partial<ChatResponse>
type Entry = Turn | { kind: 'event'; at: number; event: HudEvent }

// The feed runs to 120 rows. All of them in the log would bury the conversation,
// so the column holds the recent ones and the feed itself keeps the rest.
const EVENT_WINDOW = 40

const copy = {
  en: {
    title: 'QUEEN', hide: 'Hide', show: 'Ask the Queen',
    context: 'In context', offline: 'OFFLINE', online: 'LIVE', checking: 'CHECKING',
    offlineNote: 'No Queen is answering. Start one with `tri serve --chat`, or point VITE_QUEEN_CHAT_URL at a deployed one. Nothing here is answered from a sample.',
    empty: 'She sees what is on screen and what the board just did. Ask about any of it.',
    failed: 'The Queen did not answer.',
    about: 'Ask about this',
    subject: 'Asking about',
    clearSubject: 'Drop the subject',
    events: 'events',
  },
  ru: {
    title: 'КОРОЛЕВА', hide: 'Скрыть', show: 'Спросить королеву',
    context: 'В контексте', offline: 'OFFLINE', online: 'LIVE', checking: 'ПРОВЕРКА',
    offlineNote: 'Королева не отвечает. Поднимите её через `tri serve --chat` или укажите VITE_QUEEN_CHAT_URL на развёрнутую. Ни один ответ здесь не берётся из образца.',
    empty: 'Она видит, что на экране и что доска только что сделала. Спрашивайте о любом из этого.',
    failed: 'Королева не ответила.',
    about: 'Спросить об этом',
    subject: 'Разговор о',
    clearSubject: 'Убрать предмет',
    events: 'событий',
  },
} as const

// The chat contract carries a message and nothing else, so what she is looking
// at travels as a prefix rather than as a field the backend does not have.
function contextLine(ctx: QueenChatContext, subject: HudEvent | null): string {
  const parts = [`view=${ctx.view}`]
  if (ctx.repo) parts.push(`repo=${ctx.repo}`)
  if (ctx.spec) parts.push(`spec=${ctx.spec}`)
  if (subject) parts.push(`event=${subject.kind}${subject.issue ? `#${subject.issue}` : ''}`)
  return parts.join(' ')
}

export default function QueenChat({
  context, lang, events = [], describe, issueHref,
}: {
  context: QueenChatContext
  lang: 'ru' | 'en'
  events?: HudEvent[]
  describe?: (event: HudEvent) => string
  issueHref?: (event: HudEvent) => string | null
}) {
  const t = copy[lang === 'ru' ? 'ru' : 'en']
  const [open, setOpen] = useState(() => {
    try { return localStorage.getItem('queen-chat-open') !== '0' } catch { return true }
  })
  const [live, setLive] = useState<boolean | null>(null)
  const [turns, setTurns] = useState<Turn[]>([])
  const [subject, setSubject] = useState<HudEvent | null>(null)
  const [busy, setBusy] = useState(false)
  const log = useRef<HTMLDivElement>(null)

  useEffect(() => {
    try { localStorage.setItem('queen-chat-open', open ? '1' : '0') } catch { /* private mode */ }
  }, [open])

  // Health is polled rather than assumed: an unanswered Queen has to read as
  // offline, never as an empty conversation that looks ready.
  useEffect(() => {
    let alive = true
    const probe = () => { queenHealth().then((ok) => { if (alive) setLive(ok) }).catch(() => { if (alive) setLive(false) }) }
    probe()
    const id = window.setInterval(probe, 20000)
    return () => { alive = false; window.clearInterval(id) }
  }, [])

  // One stream, in time order: what the board did and what was said about it.
  const entries = useMemo<Entry[]>(() => {
    const rows: Entry[] = events
      .slice(-EVENT_WINDOW)
      .map((event) => ({ kind: 'event' as const, at: Date.parse(event.at) || 0, event }))
    return [...rows, ...turns].sort((a, b) => a.at - b.at)
  }, [events, turns])

  useEffect(() => { log.current?.scrollTo({ top: log.current.scrollHeight }) }, [entries.length, busy])

  const send = useCallback((text: string) => {
    const question = text.trim()
    if (!question || busy) return
    const at = Date.now()
    const line = contextLine(context, subject)
    const quoted = subject ? ` ${describe ? describe(subject) : subject.title}` : ''
    setTurns((prev) => [...prev, { kind: 'turn', at, role: 'user', content: question }])
    setBusy(true)
    askQueen(`[${line}]${quoted ? ` ${quoted}` : ''} ${question}`)
      .then((res) => setTurns((prev) => [...prev, { kind: 'turn', at: Date.now(), role: 'assistant', ...res, content: res.response }]))
      .catch(() => {
        setLive(false)
        setTurns((prev) => [...prev, { kind: 'turn', at: Date.now(), role: 'assistant', content: t.failed, source: 'offline', confidence: 0 }])
      })
      .finally(() => setBusy(false))
  }, [busy, context, subject, describe, t.failed])

  if (!open) {
    return (
      <button type="button" className="queen-chat-tab" onClick={() => setOpen(true)} aria-expanded={false}>
        {t.show}
      </button>
    )
  }

  return (
    <section className="queen-chat" aria-label={t.title}>
      <header className="queen-chat-head">
        <span className="queen-chat-title">{t.title}</span>
        <span className={`queen-chat-state is-${live === null ? 'checking' : live ? 'live' : 'offline'}`}>
          {live === null ? t.checking : live ? t.online : t.offline}
        </span>
        <span className="queen-chat-count">{queenModelName()} · {events.length} {t.events}</span>
        <button type="button" className="queen-chat-hide" onClick={() => setOpen(false)} aria-expanded>
          {t.hide}
        </button>
      </header>

      <p className="queen-chat-context">
        <span>{t.context}:</span> <code>{contextLine(context, subject)}</code>
      </p>

      <div className="queen-chat-log" ref={log}>
        {entries.length === 0 && <p className="queen-chat-empty">{live === false ? t.offlineNote : t.empty}</p>}
        {entries.map((entry, i) => entry.kind === 'event' ? (
          <article
            key={`e:${entry.event.id}`}
            className={`queen-chat-event${subject?.id === entry.event.id ? ' is-subject' : ''}`}
            data-kind={entry.event.kind}
          >
            <p>{describe ? describe(entry.event) : entry.event.title}</p>
            <div className="queen-chat-event-actions">
              <button type="button" onClick={() => setSubject(entry.event)}>{t.about}</button>
              {issueHref && issueHref(entry.event) && (
                <a href={issueHref(entry.event) as string} target="_blank" rel="noopener noreferrer">
                  #{entry.event.issue}
                </a>
              )}
            </div>
          </article>
        ) : (
          <ChatMessage
            key={`t:${i}:${entry.at}`}
            role={entry.role}
            content={entry.content}
            source={entry.source}
            confidence={entry.confidence}
            latency_us={entry.latency_us}
          />
        ))}
      </div>

      {subject && (
        <p className="queen-chat-subject">
          <span>{t.subject}:</span> <b>{describe ? describe(subject) : subject.title}</b>
          <button type="button" onClick={() => setSubject(null)}>{t.clearSubject}</button>
        </p>
      )}

      <ChatInput onSend={send} disabled={busy} />
    </section>
  )
}
