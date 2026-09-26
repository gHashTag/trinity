import { Suspense, lazy, useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { elapsed, useCellLive, type CellEvent } from '../lib/queenIssueLive'
import { useCollab, postIssueComment } from '../lib/queenCollab'
import { loadWorldIssueDetailsCached, type WorldIssue } from './queenRepositoryWorld'
import './QueenCellStage.css'

const QueenChat = lazy(() => import('./QueenChat'))

// The cell, opened.
//
// A click on a cell used to put a 320px aside beside a map that kept moving.
// Everything the visitor wanted was in it and none of it was legible: the
// description scrolled in a box six lines tall, what the bee was doing was on a
// different screen, and there was nowhere to say anything. This is the same cell
// at the size of the display: the hexagon is drawn to the viewport, and the task,
// the bee's own log and the Queen sit inside it.
//
// Three rules hold here:
//   - every figure is a field of an endpoint or it is an em dash. There is no
//     "active now" that is not the board's own column, and no elapsed time that
//     is not the difference of two timestamps this page was handed;
//   - the GitHub description is quoted, not translated, and carries the
//     lang-exempt boundary the rest of the map already uses;
//   - the write box is gated on what t27-github-collab says it can do. What it
//     cannot do is said in words rather than hidden.

const HEX = '50,1 96,25.5 96,74.5 50,99 4,74.5 4,25.5'

// The board's six columns, in the map's own colours. A column the board adds
// later is drawn in the neutral tone rather than dropped.
const COLUMN_RGB: Record<string, string> = {
  running: '0 255 136',
  review: '255 212 90',
  done: '100 220 255',
  backlog: '168 193 186',
  blocked: '255 77 94',
  dropped: '107 125 120',
}

const COPY = {
  en: {
    close: 'Close',
    esc: 'Esc',
    task: 'The task',
    board: 'On the board',
    column: 'Column',
    criteria: 'Acceptance criteria',
    needs: 'Missing from the brief',
    state: 'GitHub state',
    assignees: 'GitHub assignees',
    nobody: 'nobody',
    notReservation: 'An assignee is not a lease. Check open pull requests before starting.',
    description: 'GitHub description',
    loading: 'Loading…',
    noBody: 'This issue has no description.',
    failed: 'GitHub is unavailable or rate-limited.',
    retry: 'Retry',
    notOnBoard: 'The supervisor board does not carry this number. It has not been dispatched.',
    boardDown: 'The board did not answer',
    bee: 'The bee, live',
    beeNote: 'Every line is an event the supervisor published for this number.',
    noEvents: 'No event named this issue in the last 24 hours.',
    activityDown: 'The activity feed did not answer',
    lastEvent: 'Newest event',
    lastRound: 'Last round closed',
    chat: 'Say something',
    chatNote: 'The Queen reads this cell and the board. She answers from the deployed supervisor, never from a sample.',
    github: 'Write on GitHub',
    githubGap: 'The site cannot post to GitHub for you: t27-github-collab is reachable but does not offer an issue-comment capability. Copy the comment and post it from the issue, where you are signed in.',
    githubDown: 't27-github-collab did not answer, so no GitHub write is offered.',
    githubChecking: 'Checking t27-github-collab…',
    comment: 'Comment',
    commentPlaceholder: 'What you want the owner and the bee to read',
    copyComment: 'Copy comment',
    copyUrl: 'Copy issue URL',
    copyCell: 'Copy link to this cell',
    packet: 'COPY TO AGENT',
    packetNote: 'The packet does not claim the work. Check assignees and open pull requests before starting.',
    specs: 'Related specs · not proof',
    noSpecs: 'The catalog links no .t27 spec to this cell.',
    post: 'Post to GitHub',
    posted: 'Posted',
    postFailed: 'GitHub post failed',
    copied: 'Copied',
    copyManually: 'Copy the text below',
    ago: 'ago',
    zoom: 'Cell close-up',
  },
  ru: {
    close: 'Закрыть',
    esc: 'Esc',
    task: 'Задача',
    board: 'На доске',
    column: 'Колонка',
    criteria: 'Критерии приёмки',
    needs: 'Чего не хватает в брифе',
    state: 'Состояние GitHub',
    assignees: 'Исполнители GitHub',
    nobody: 'никого',
    notReservation: 'Исполнитель — не бронь. Перед работой проверьте открытые pull request.',
    description: 'Описание GitHub',
    loading: 'Загрузка…',
    noBody: 'У задачи нет описания.',
    failed: 'GitHub недоступен или достигнут лимит.',
    retry: 'Повторить',
    notOnBoard: 'На доске супервизора этого номера нет. Задача не была отправлена в работу.',
    boardDown: 'Доска не ответила',
    bee: 'Пчела, вживую',
    beeNote: 'Каждая строка — событие, которое супервизор опубликовал по этому номеру.',
    noEvents: 'За последние 24 часа ни одно событие не назвало эту задачу.',
    activityDown: 'Лента событий не ответила',
    lastEvent: 'Последнее событие',
    lastRound: 'Последний раунд закрыт',
    chat: 'Сказать',
    chatNote: 'Королева видит эту соту и доску. Отвечает развёрнутый супервизор, а не образец.',
    github: 'Написать в GitHub',
    githubGap: 'Сайт не может написать в GitHub за вас: t27-github-collab отвечает, но не объявляет возможность комментирования. Скопируйте текст и опубликуйте его из задачи, где вы уже вошли.',
    githubDown: 't27-github-collab не ответил, поэтому запись в GitHub не предлагается.',
    githubChecking: 'Проверяю t27-github-collab…',
    comment: 'Комментарий',
    commentPlaceholder: 'Что должны прочитать владелец и пчела',
    copyComment: 'Скопировать комментарий',
    copyUrl: 'Скопировать ссылку на задачу',
    copyCell: 'Скопировать ссылку на соту',
    packet: 'COPY TO AGENT',
    packetNote: 'Пакет не назначает задачу. Перед работой проверьте исполнителя и открытые pull request.',
    specs: 'Связанные спеки · не доказательство',
    noSpecs: 'Каталог не связывает с этой сотой ни одной спеки .t27.',
    post: 'Отправить в GitHub',
    posted: 'Отправлено',
    postFailed: 'Не удалось отправить в GitHub',
    copied: 'Скопировано',
    copyManually: 'Скопируйте текст ниже',
    ago: 'назад',
    zoom: 'Крупный план соты',
  },
} as const

function EventRow({ event, now, ago }: { event: CellEvent; now: number; ago: string }) {
  const since = elapsed(event.at, now)
  return (
    <li className="queen-cell-event" data-kind={event.kind}>
      <b>{event.kind}</b>
      <time dateTime={event.at}>{since ? `${since} ${ago}` : '—'}</time>
      <span data-lang-exempt="github-title">{event.title}</span>
    </li>
  )
}

/** A spec the catalog links to this cell, and the source file to open for it. */
export type CellSpecLink = { path: string; label: string; note: string }

export default function QueenCellStage({
  repo, number, title, lang, onClose, cellHref, specs, onSpec, packet, onObserved,
}: {
  repo: string
  number: number
  /** The catalog's own title, shown until GitHub answers with its own. */
  title?: string
  lang: 'ru' | 'en'
  onClose: () => void
  /** A shareable address for this cell, when the caller has one. */
  cellHref?: string
  /** Specs the caller's catalog already links to this number. */
  specs?: CellSpecLink[]
  /** Open one of those specs in the explorer. Without it the links are not drawn. */
  onSpec?: (path: string) => void
  /** The agent packet, built by the caller that holds the atlas. */
  packet?: () => string
  /** The GitHub row, handed back so the map can redraw the cell it just read. */
  onObserved?: (row: WorldIssue) => void
}) {
  const t = COPY[lang === 'ru' ? 'ru' : 'en']
  const live = useCellLive(number)
  const collab = useCollab()
  // One state for the fetch, stamped with the request that produced it. The
  // stamp is what resets the panel when the cell changes: a result for another
  // cell reads as "still loading" rather than being cleared by a setState in
  // the effect body, which would cost a second render every time.
  const [fetched, setFetched] = useState<{ key: string; row: WorldIssue | null; error: boolean }>({ key: '', row: null, error: false })
  const [retry, setRetry] = useState(0)
  const [comment, setComment] = useState('')
  const [notice, setNotice] = useState<{ tone: 'ok' | 'manual' | 'error'; text: string; body?: string } | null>(null)
  const [now, setNow] = useState(() => Date.now())
  const closeRef = useRef<HTMLButtonElement>(null)
  const logRef = useRef<HTMLOListElement>(null)

  // The relative times are recomputed on a clock of their own, so "4s ago" does
  // not sit at 4s until the next poll happens to re-render the panel.
  useEffect(() => {
    const tick = window.setInterval(() => setNow(Date.now()), 1000)
    return () => window.clearInterval(tick)
  }, [])

  useEffect(() => { closeRef.current?.focus() }, [])

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => { if (event.key === 'Escape') onClose() }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [onClose])

  const request = `${repo}#${number}#${retry}`
  const issue = fetched.key === request ? fetched.row : null
  const issueError = fetched.key === request ? fetched.error : false

  // The observer is held in a ref so that a caller which rebuilds the callback
  // on every render cannot turn one GitHub read into a request per render.
  const observe = useRef(onObserved)
  useEffect(() => { observe.current = onObserved }, [onObserved])

  useEffect(() => {
    const abort = new AbortController()
    loadWorldIssueDetailsCached(repo, number, abort.signal, retry > 0)
      .then((row) => {
        if (abort.signal.aborted) return
        setFetched({ key: request, row, error: false })
        observe.current?.(row)
      })
      .catch(() => { if (!abort.signal.aborted) setFetched({ key: request, row: null, error: true }) })
    return () => abort.abort()
  }, [repo, number, retry, request])

  useEffect(() => { logRef.current?.scrollTo({ top: logRef.current.scrollHeight }) }, [live.events.length])

  const issueUrl = `https://github.com/${repo}/issues/${number}`
  const rgb = COLUMN_RGB[live.card?.column ?? ''] ?? COLUMN_RGB.backlog
  const heading = issue?.title ?? title ?? `#${number}`

  const copy = useCallback(async (text: string, label: string) => {
    try {
      await navigator.clipboard.writeText(text)
      setNotice({ tone: 'ok', text: `${label} · ${t.copied}` })
    } catch {
      setNotice({ tone: 'manual', text: t.copyManually, body: text })
    }
  }, [t.copied, t.copyManually])

  const post = useCallback(() => {
    const body = comment.trim()
    if (!body) return
    postIssueComment(repo, number, body)
      .then(() => { setNotice({ tone: 'ok', text: t.posted }); setComment('') })
      .catch((error: unknown) => setNotice({ tone: 'error', text: `${t.postFailed}: ${error instanceof Error ? error.message : String(error)}` }))
  }, [comment, repo, number, t.posted, t.postFailed])

  const chatContext = useMemo(() => ({ view: `cell:${number}`, repo, spec: null }), [number, repo])

  return (
    <div className="queen-cell-stage" role="dialog" aria-modal="true" aria-label={`${t.zoom}: ${repo} #${number}`}>
      {/* The cell itself, drawn to the display. Decoration: everything it says
          is said again in the panels inside it. */}
      <svg className="queen-cell-hex" viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true" style={{ '--cell-rgb': rgb } as React.CSSProperties}>
        <polygon points={HEX} />
        {live.card?.column === 'running' && <polygon className="queen-cell-hex-pulse" points={HEX} />}
      </svg>

      <header className="queen-cell-head">
        <span className="queen-cell-id">{repo} #{number}</span>
        <span className="queen-cell-column" style={{ '--cell-rgb': rgb } as React.CSSProperties}>
          {live.card ? (live.column?.title ?? live.card.column) : live.boardRead ? '—' : '…'}
        </span>
        {live.column?.blurb && <small className="queen-cell-blurb">{live.column.blurb}</small>}
        <button type="button" className="queen-cell-close" ref={closeRef} onClick={onClose}>
          {t.close} <kbd>{t.esc}</kbd>
        </button>
      </header>

      <h2 className="queen-cell-title" data-lang-exempt="github-title">{heading}</h2>

      <div className="queen-cell-grid">
        <section className="queen-cell-panel" aria-label={t.task}>
          <h3>{t.task}</h3>
          <dl className="queen-cell-facts">
            <dt>{t.state}</dt>
            <dd>{issue ? issue.state : issueError ? '—' : t.loading}</dd>
            <dt>{t.assignees}</dt>
            <dd>{issue ? (issue.assignees?.join(', ') || t.nobody) : '—'}</dd>
            <dt>{t.criteria}</dt>
            <dd>{live.card?.criteria ?? (live.boardRead ? '—' : '…')}</dd>
            <dt>{t.needs}</dt>
            <dd>{live.card?.needs?.length ? live.card.needs.join(', ') : live.boardRead ? '—' : '…'}</dd>
          </dl>
          <p className="queen-cell-note">{t.notReservation}</p>
          {!live.card && live.boardRead && <p className="queen-cell-note">{t.notOnBoard}</p>}
          {live.boardError && <p role="alert">{t.boardDown}: {live.boardError}</p>}
          {issueError && (
            <p role="alert">
              {t.failed}
              <button type="button" onClick={() => setRetry((n) => n + 1)}>{t.retry}</button>
            </p>
          )}
          <h4>{t.description}</h4>
          <pre className="queen-cell-body" data-lang-exempt="github-content">
            {issue ? (issue.body || t.noBody) : issueError ? t.failed : t.loading}
          </pre>

          {onSpec && (
            <>
              <h4>{t.specs} · {specs?.length ?? 0}</h4>
              {specs?.length
                ? <ul className="queen-cell-specs">
                    {specs.map((link) => (
                      <li key={link.path}>
                        <button type="button" onClick={() => onSpec(link.path)}>{link.label}</button>
                        <small>{link.note}</small>
                      </li>
                    ))}
                  </ul>
                : <p className="queen-cell-note">{t.noSpecs}</p>}
            </>
          )}

          {packet && (
            <div className="queen-cell-actions">
              <button type="button" onClick={() => void copy(packet(), t.packet)}>{t.packet}</button>
            </div>
          )}
          {packet && <p className="queen-cell-note">{t.packetNote}</p>}
        </section>

        <section className="queen-cell-panel" aria-label={t.bee}>
          <h3>{t.bee}</h3>
          <p className="queen-cell-note">{t.beeNote}</p>
          <dl className="queen-cell-facts">
            <dt>{t.lastEvent}</dt>
            <dd>{live.lastEventAt ? `${elapsed(live.lastEventAt, now) ?? '—'} ${t.ago}` : live.activityRead ? '—' : '…'}</dd>
            <dt>{t.lastRound}</dt>
            <dd>{live.lastRoundAt ? `${elapsed(live.lastRoundAt, now) ?? '—'} ${t.ago}` : live.boardRead ? '—' : '…'}</dd>
          </dl>
          {live.activityError && <p role="alert">{t.activityDown}: {live.activityError}</p>}
          <ol className="queen-cell-log" ref={logRef}>
            {live.events.map((event) => <EventRow key={event.id} event={event} now={now} ago={t.ago} />)}
          </ol>
          {live.events.length === 0 && live.activityRead && <p className="queen-cell-note">{t.noEvents}</p>}
        </section>

        <section className="queen-cell-panel queen-cell-say" aria-label={t.chat}>
          <h3>{t.chat}</h3>
          <p className="queen-cell-note">{t.chatNote}</p>
          <Suspense fallback={null}>
            <QueenChat lang={lang} context={chatContext} />
          </Suspense>

          <h4>{t.github}</h4>
          {collab.state === 'checking' && <p className="queen-cell-note">{t.githubChecking}</p>}
          {collab.state === 'down' && <p className="queen-cell-note">{t.githubDown}</p>}
          {collab.state === 'up' && !collab.capabilities.comment && <p className="queen-cell-note">{t.githubGap}</p>}
          <label className="queen-cell-comment">
            <span>{t.comment}</span>
            <textarea
              value={comment}
              placeholder={t.commentPlaceholder}
              onChange={(event) => setComment(event.target.value)}
            />
          </label>
          <div className="queen-cell-actions">
            {collab.capabilities.comment && (
              <button type="button" disabled={comment.trim() === ''} onClick={post}>{t.post}</button>
            )}
            <button type="button" disabled={comment.trim() === ''} onClick={() => void copy(comment.trim(), t.copyComment)}>{t.copyComment}</button>
            <button type="button" onClick={() => void copy(issueUrl, t.copyUrl)}>{t.copyUrl}</button>
            {cellHref && <button type="button" onClick={() => void copy(cellHref, t.copyCell)}>{t.copyCell}</button>}
          </div>
          {notice && (
            <>
              <p role="status" data-tone={notice.tone}>{notice.text}</p>
              {notice.body !== undefined && <textarea readOnly aria-label={t.copyManually} value={notice.body} />}
            </>
          )}
        </section>
      </div>
    </div>
  )
}
