import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import ChatInput from './chat/ChatInput'
import ChatMessage from './chat/ChatMessage'
import { NotSignedIn, type ChatResponse } from '../services/chatApi'
import { askQueen, askQueenInBrowser, queenCaller, queenHealth, queenModelName } from '../services/queenModel'
import { signInHref } from '../lib/triIdentity'
import { HUD_VIEWS, type HudEvent, type HudEventKind } from './queenHud'
import {
  a2aNetwork, CHAT_TABS, filterEvents, kindCounts, NO_FILTER,
  type ChatTab, type LogFilter,
} from './queenChatNetwork'
import './QueenChat.css'

export interface QueenChatContext {
  view: string
  spec?: string | null
  repo?: string | null
}

type Turn = { kind: 'turn'; at: number; role: 'user' | 'assistant'; content: string } & Partial<ChatResponse>

// The feed runs to 120 rows. The LOGS tab holds all of them, because that is
// what it is for; the number is kept here so the A2A tab can say which window
// its links were counted over rather than implying they are the whole swarm.
const EVENT_WINDOW = 120

const copy = {
  en: {
    title: 'QUEEN', hide: 'Hide', show: 'Ask the Queen',
    context: 'In context', offline: 'OFFLINE', online: 'LIVE', checking: 'CHECKING',
    offlineNote: 'No Queen is answering. Start one with `tri serve --chat`, or point VITE_QUEEN_CHAT_URL at a deployed one. Nothing here is answered from a sample.',
    empty: 'Ask her about the board. She sees the view you are on; the traffic it makes is in LOGS, and who it travelled between is in A2A.',
    failed: 'The Queen did not answer.',
    about: 'Ask about this',
    subject: 'Asking about',
    clearSubject: 'Drop the subject',
    events: 'events',
    thinking: 'The Queen is answering',
    signedOut: 'The Queen answers people she knows. Sign in with Telegram and ask her here.',
    signIn: 'Sign in',
    signInTitle: 'Sign in with Telegram and come back to this view',
    tabQueen: 'QUEEN', tabLogs: 'LOGS', tabA2A: 'A2A',
    tabQueenTitle: 'The conversation', tabLogsTitle: 'Everything the board did, filtered', tabA2ATitle: 'Who the traffic travelled between',
    filterKinds: 'Kinds', filterText: 'issue number, or a word',
    filterClear: 'Clear', filterShowing: 'showing',
    logEmpty: 'Nothing in the feed matches that.',
    netNote: 'The feed carries an issue on every row and no worker name anywhere: /a2a answers 403, /queen/agents 404 (measured 2026-09-21). So the network is the Queen at the hub and one link per issue, with each message counted in the direction it travelled.',
    netLinks: 'links', netMessages: 'messages',
    netUp: 'to the Queen', netDown: 'to a worker',
    netBusy: 'busy now',
    netScope: 'The links are counted over the last {n} events. The busy figure is the swarm’s own, at this moment. They count different things and are not meant to agree.',
    netEmpty: 'No traffic in the window.',
    netUnattributed: 'rows carried no issue',
    stance: { accepted: 'accepted', 'with-worker': 'with a worker', 'with-queen': 'with the Queen' },
  },
  ru: {
    title: 'КОРОЛЕВА', hide: 'Скрыть', show: 'Спросить королеву',
    context: 'В контексте', offline: 'OFFLINE', online: 'LIVE', checking: 'ПРОВЕРКА',
    offlineNote: 'Королева не отвечает. Поднимите её через `tri serve --chat` или укажите VITE_QUEEN_CHAT_URL на развёрнутую. Ни один ответ здесь не берётся из образца.',
    empty: 'Спрашивайте её о доске. Она видит вид, на котором вы стоите; его трафик — во вкладке ЛОГИ, а между кем он шёл — в A2A.',
    failed: 'Королева не ответила.',
    about: 'Спросить об этом',
    subject: 'Разговор о',
    clearSubject: 'Убрать предмет',
    events: 'событий',
    thinking: 'Королева отвечает',
    signedOut: 'Королева отвечает тем, кого знает. Войдите через Telegram и спрашивайте здесь.',
    signIn: 'Войти',
    signInTitle: 'Войти через Telegram и вернуться к этому виду',
    tabQueen: 'КОРОЛЕВА', tabLogs: 'ЛОГИ', tabA2A: 'A2A',
    tabQueenTitle: 'Диалог', tabLogsTitle: 'Всё, что сделала доска, с фильтром', tabA2ATitle: 'Между кем шёл трафик',
    filterKinds: 'Виды', filterText: 'номер задачи или слово',
    filterClear: 'Сбросить', filterShowing: 'показано',
    logEmpty: 'В ленте нет ничего подходящего.',
    netNote: 'В ленте на каждой строке есть задача и нигде нет имени рабочего: /a2a отвечает 403, /queen/agents — 404 (измерено 2026-09-21). Поэтому сеть — это королева в центре и одна связь на задачу, а каждое сообщение посчитано в ту сторону, в которую оно шло.',
    netLinks: 'связей', netMessages: 'сообщений',
    netUp: 'королеве', netDown: 'рабочему',
    netBusy: 'в работе сейчас',
    netScope: 'Связи посчитаны по последним {n} событиям. Число занятых — собственное число роя на эту секунду. Это разные величины, и совпадать они не обязаны.',
    netEmpty: 'В окне нет трафика.',
    netUnattributed: 'строк без задачи',
    stance: { accepted: 'принято', 'with-worker': 'у рабочего', 'with-queen': 'у королевы' },
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
  context, lang, events = [], describe, issueHref, workers = null,
}: {
  context: QueenChatContext
  lang: 'ru' | 'en'
  events?: HudEvent[]
  describe?: (event: HudEvent) => string
  issueHref?: (event: HudEvent) => string | null
  /** The swarm's own count of paid slots, for the A2A tab. Never derived here. */
  workers?: { capacity: number; active: number; idle: number } | null
}) {
  const t = copy[lang === 'ru' ? 'ru' : 'en']
  const [open, setOpen] = useState(() => {
    try { return localStorage.getItem('queen-chat-open') !== '0' } catch { return true }
  })
  // The conversation is the tab she opens on. The other two are places to look
  // something up and come back from, which is why "Ask about this" in either of
  // them lands here with the subject already set.
  const [tab, setTab] = useState<ChatTab>('queen')
  const [live, setLive] = useState<boolean | null>(null)
  // Whether there is anybody signed in — a boolean, never the token. The
  // component cannot leak what it was never given, and the token itself is read
  // fresh at the moment a question is sent (queenModel.askQueen), so nothing
  // here can go stale into a request.
  const [signedIn, setSignedIn] = useState(() => queenCaller().signedIn)
  const [turns, setTurns] = useState<Turn[]>([])
  const [subject, setSubject] = useState<HudEvent | null>(null)
  const [filter, setFilter] = useState<LogFilter>(NO_FILTER)
  const [busy, setBusy] = useState(false)
  // How long she has been at it. A model that thinks for half a minute and a
  // model that is not there look the same from a chair: nothing arrives. The
  // seconds are counted, not estimated, and no progress is implied.
  const [waited, setWaited] = useState(0)
  const log = useRef<HTMLDivElement>(null)

  useEffect(() => {
    try { localStorage.setItem('queen-chat-open', open ? '1' : '0') } catch { /* private mode */ }
  }, [open])

  // Health is polled rather than assumed: an unanswered Queen has to read as
  // offline, never as an empty conversation that looks ready.
  useEffect(() => {
    let alive = true
    const probe = () => {
      // Asked on the same beat: a session that expired while the panel was open
      // has to close the input, and a sign-in that happened in another tab of
      // this app has to open it, without a reload either way.
      setSignedIn(queenCaller().signedIn)
      queenHealth().then((ok) => { if (alive) setLive(ok) }).catch(() => { if (alive) setLive(false) })
    }
    probe()
    const id = window.setInterval(probe, 20000)
    return () => { alive = false; window.clearInterval(id) }
  }, [])

  const feed = useMemo(() => events.slice(-EVENT_WINDOW), [events])
  const shown = useMemo(() => filterEvents(feed, filter), [feed, filter])
  const counts = useMemo(() => kindCounts(feed), [feed])
  const net = useMemo(() => a2aNetwork(feed), [feed])
  const filtered = filter.kinds.length > 0 || filter.text.trim() !== ''

  // The conversation runs forward in time, the way a conversation does. The two
  // derived tabs run newest-first, because they are read by looking rather than
  // by following, and a filter that answers at the bottom of a scroller has not
  // answered.
  useEffect(() => {
    if (tab !== 'queen') return
    log.current?.scrollTo({ top: log.current.scrollHeight })
  }, [tab, turns.length, busy])

  // The clock is started where the question is sent, not here: setting state in
  // an effect's body re-renders before the browser has painted the one it is
  // already in.
  useEffect(() => {
    if (!busy) return
    const started = Date.now()
    const tick = setInterval(() => setWaited(Math.round((Date.now() - started) / 1000)), 1000)
    return () => clearInterval(tick)
  }, [busy])

  const ask = useCallback((event: HudEvent) => { setSubject(event); setTab('queen') }, [])

  const toggleKind = useCallback((kind: HudEventKind) => {
    setFilter((prev) => ({
      ...prev,
      kinds: prev.kinds.includes(kind) ? prev.kinds.filter((k) => k !== kind) : [...prev.kinds, kind],
    }))
  }, [])

  const send = useCallback((text: string) => {
    const question = text.trim()
    if (!question || busy) return
    const at = Date.now()
    const line = contextLine(context, subject)
    const quoted = subject ? ` ${describe ? describe(subject) : subject.title}` : ''
    setTurns((prev) => [...prev, { kind: 'turn', at, role: 'user', content: question }])
    setWaited(0)
    setBusy(true)
    // On the BROWSER tab the question goes to the person's own agent, which
    // holds the browser tools; everywhere else, to the Queen as before
    // (lib/queenBrowser.ts, askBrowserAgent, says why).
    const history = turns
      .filter((turn) => turn.source !== 'offline')
      .map((turn) => ({ role: turn.role, content: turn.content }))
    const asked: Promise<ChatResponse> =
      context.view === 'browser'
        ? askQueenInBrowser(history, question, lang)
        : askQueen(`[${line}]${quoted ? ` ${quoted}` : ''} ${question}`)
    asked
      .then((res) => setTurns((prev) => [...prev, { kind: 'turn', at: Date.now(), role: 'assistant', ...res, content: res.response }]))
      .catch((error: unknown) => {
        // Signed out is not the Queen failing, and must not be reported as one:
        // she is answering other people at this moment. The panel closes the
        // input and says where to go instead.
        if (error instanceof NotSignedIn) { setSignedIn(false); return }
        setLive(false)
        // Why, when there is a why. Her server reports a quota or a refusal in
        // words, and the proxy passes them through; a bare "did not answer"
        // turned every one of those into the same silence.
        const said = error instanceof Error ? error.message.trim() : ''
        setTurns((prev) => [...prev, { kind: 'turn', at: Date.now(), role: 'assistant', content: said ? `${t.failed} ${said}` : t.failed, source: 'offline', confidence: 0 }])
      })
      .finally(() => setBusy(false))
  }, [busy, context, subject, describe, t.failed, turns, lang])

  if (!open) {
    return (
      <button type="button" className="queen-chat-tab" onClick={() => setOpen(true)} aria-expanded={false}>
        {t.show}
      </button>
    )
  }

  const label: Record<ChatTab, string> = { queen: t.tabQueen, logs: t.tabLogs, a2a: t.tabA2A }
  const hint: Record<ChatTab, string> = { queen: t.tabQueenTitle, logs: t.tabLogsTitle, a2a: t.tabA2ATitle }
  const badge: Record<ChatTab, number | null> = { queen: turns.length || null, logs: feed.length || null, a2a: net.links.length || null }

  const eventRow = (event: HudEvent) => (
    <article
      key={`e:${event.id}`}
      className={`queen-chat-event${subject?.id === event.id ? ' is-subject' : ''}`}
      data-kind={event.kind}
    >
      <p>{describe ? describe(event) : event.title}</p>
      <div className="queen-chat-event-actions">
        <button type="button" onClick={() => ask(event)}>{t.about}</button>
        {issueHref && issueHref(event) && (
          <a href={issueHref(event) as string} target="_blank" rel="noopener noreferrer">
            #{event.issue}
          </a>
        )}
      </div>
    </article>
  )

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

      <nav className="queen-chat-tabs" role="tablist" aria-label={t.title}>
        {CHAT_TABS.map((name) => (
          <button
            key={name}
            type="button"
            role="tab"
            id={`queen-chat-tab-${name}`}
            aria-selected={tab === name}
            aria-controls={`queen-chat-panel-${name}`}
            title={hint[name]}
            className={`queen-chat-tabbtn${tab === name ? ' is-on' : ''}`}
            onClick={() => setTab(name)}
          >
            {label[name]}
            {badge[name] !== null && <b>{badge[name]}</b>}
          </button>
        ))}
      </nav>

      {tab === 'queen' && (
        <p className="queen-chat-context">
          <span>{t.context}:</span> <code>{contextLine(context, subject)}</code>
        </p>
      )}

      <div
        className="queen-chat-body"
        role="tabpanel"
        id={`queen-chat-panel-${tab}`}
        aria-labelledby={`queen-chat-tab-${tab}`}
      >
        {tab === 'queen' && (
          <div className="queen-chat-log" ref={log}>
            {turns.length === 0 && <p className="queen-chat-empty">{live === false ? t.offlineNote : t.empty}</p>}
            {turns.map((turn, i) => (
              <ChatMessage
                key={`t:${i}:${turn.at}`}
                role={turn.role}
                content={turn.content}
                source={turn.source}
                confidence={turn.confidence}
                latency_us={turn.latency_us}
              />
            ))}
            {busy && (
              <p className="queen-chat-pending" aria-live="polite">
                {t.thinking}
                <b>{waited}s</b>
              </p>
            )}
          </div>
        )}

        {tab === 'logs' && (
          <>
            <div className="queen-chat-filter">
              <div className="queen-chat-chips" role="group" aria-label={t.filterKinds}>
                {counts.map(({ kind, count }) => (
                  <button
                    key={kind}
                    type="button"
                    aria-pressed={filter.kinds.includes(kind)}
                    className={`queen-chat-chip${filter.kinds.includes(kind) ? ' is-on' : ''}`}
                    data-kind={kind}
                    onClick={() => toggleKind(kind)}
                  >
                    {kind}<b>{count}</b>
                  </button>
                ))}
              </div>
              <div className="queen-chat-find">
                <input
                  type="search"
                  value={filter.text}
                  placeholder={t.filterText}
                  aria-label={t.filterText}
                  onChange={(e) => setFilter((prev) => ({ ...prev, text: e.target.value }))}
                />
                <span className="queen-chat-count">{t.filterShowing} {shown.length}/{feed.length}</span>
                {filtered && (
                  <button type="button" className="queen-chat-clear" onClick={() => setFilter(NO_FILTER)}>
                    {t.filterClear}
                  </button>
                )}
              </div>
            </div>
            <div className="queen-chat-log">
              {shown.length === 0 && <p className="queen-chat-empty">{t.logEmpty}</p>}
              {[...shown].reverse().map(eventRow)}
            </div>
          </>
        )}

        {tab === 'a2a' && (
          <div className="queen-chat-net">
            <dl className="queen-chat-net-sum">
              <div><dt>{t.netLinks}</dt><dd>{net.links.length}</dd></div>
              <div><dt>{t.netMessages}</dt><dd>{net.messages}</dd></div>
              <div><dt>{t.netUp}</dt><dd>{net.toQueen}</dd></div>
              <div><dt>{t.netDown}</dt><dd>{net.toWorker}</dd></div>
              {workers && (
                <div><dt>{t.netBusy}</dt><dd>{workers.active}/{workers.capacity}</dd></div>
              )}
            </dl>
            <p className="queen-chat-net-note">{t.netNote}</p>
            <p className="queen-chat-net-note">
              {t.netScope.replace('{n}', String(feed.length))}
              {net.unattributed > 0 && ` · ${net.unattributed} ${t.netUnattributed}`}
            </p>
            {net.links.length === 0 && <p className="queen-chat-empty">{t.netEmpty}</p>}
            <ol className="queen-chat-links">
              {net.links.map((link) => (
                <li key={link.issue} className="queen-chat-link" data-stance={link.stance}>
                  <p className="queen-chat-link-head">
                    <b>#{link.issue}</b>
                    <span className="queen-chat-link-flow" aria-label={`${link.toWorker} ${t.netDown}, ${link.toQueen} ${t.netUp}`}>
                      <i aria-hidden="true">↓</i>{link.toWorker}
                      <i aria-hidden="true">↑</i>{link.toQueen}
                    </span>
                    <em>{t.stance[link.stance]}</em>
                  </p>
                  <p className="queen-chat-link-title">{link.title}</p>
                  <div className="queen-chat-event-actions">
                    <button type="button" onClick={() => ask(link.last)}>{t.about}</button>
                    {issueHref && issueHref(link.last) && (
                      <a href={issueHref(link.last) as string} target="_blank" rel="noopener noreferrer">
                        #{link.issue}
                      </a>
                    )}
                  </div>
                </li>
              ))}
            </ol>
          </div>
        )}
      </div>

      {tab === 'queen' && subject && (
        <p className="queen-chat-subject">
          <span>{t.subject}:</span> <b>{describe ? describe(subject) : subject.title}</b>
          <button type="button" onClick={() => setSubject(null)}>{t.clearSubject}</button>
        </p>
      )}

      {tab === 'queen' && (signedIn ? (
        <ChatInput onSend={send} disabled={busy} />
      ) : (
        // Not a disabled input: a box you can type into and never send is a
        // worse answer than a sentence that says why and where to go. The link
        // is signInHref, the same address the identity chip uses, so there is
        // one sign-in in this bundle rather than two that can drift apart.
        <p className="queen-chat-signin">
          <span>{t.signedOut}</span>
          <a href={signInHref(context.view, HUD_VIEWS)} target="_top" rel="noopener" title={t.signInTitle}>
            {t.signIn}
          </a>
        </p>
      ))}
    </section>
  )
}
