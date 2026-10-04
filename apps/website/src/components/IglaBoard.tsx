import { useEffect, useState, type CSSProperties } from 'react'
import { IGLA_BOARD } from '../lib/iglaBoard.generated'
import './IglaBoard.css'

// Every number below comes from queen/igla-board.t27, generated in
// gHashTag/igla-coder-gpu from committed artifacts; the site's generator
// recompiles it and re-derives each McNemar p before this renders.
// The live strip is the one thing read at view time, and it is labelled so.

type LiveEvent = {
  job: string
  stage?: string
  msg: string
  progress?: number | null
  ts?: string
  rx?: string
}

type LiveState = { status: 'loading' } | { status: 'down' } | { status: 'ok', jobs: LiveEvent[], serverTime: string }

const COPY = {
  en: {
    kicker: 'IGLA CODER · TERNARY 9M',
    title: 'IGLA BOARD',
    lead: 'A 9M-parameter ternary model writes t27 function bodies; t27c splices each body into its spec and runs the spec\'s own tests. The board shows what passed, what moved, and what was retracted.',
    source: 'SOURCE .T27',
    glance: 'IGLA at a glance',
    live: 'LIVE JOBS',
    liveHint: 'Read from the Railway board at view time; not part of the sealed .t27.',
    liveDown: 'Live board unreachable from this page right now.',
    liveLoading: 'reading live board…',
    liveOpen: 'OPEN LIVE BOARD',
    levers: 'MASK A/B LEVERS',
    leversHint: 'Each mask rule runs as a paired arm on the same items and engine and is tested on two generation seeds. The verdict is the pooled exact McNemar test on compile discordants.',
    lever: 'lever',
    seed: 'seed',
    compile: 'compile',
    pooled: 'pooled',
    discord: 'base-only / arm-only',
    verdict: 'verdict',
    pass: 'pass',
    pending: 'not fetched yet',
    arena: 'SELECTION ARENA',
    arenaHint: 'Checkpoints pass gates in order; a negative control must fail. Arena numbers are compared only within one arena run.',
    candidate: 'candidate',
    gates: 'gates',
    strict: 'strict pass',
    toks: 'tok/s',
    bpb: 'bpb',
    rank: 'rank',
    decision: 'arena decision',
    pipeline: 'PIPELINE',
    roadmap: 'ROADMAP',
    judge: 'judge',
    model: 'MODEL',
    sealed: 'sealed from',
    snapshot: 'snapshot',
  },
  ru: {
    kicker: 'IGLA CODER · ТЕРНАРНАЯ 9M',
    title: 'ДОСКА IGLA',
    lead: 'Тернарная модель на 9M параметров пишет тела функций t27; t27c вставляет каждое тело в его спецификацию и запускает собственные тесты спецификации. Доска показывает, что прошло, что сдвинулось и что отозвано.',
    source: 'ИСТОЧНИК .T27',
    glance: 'IGLA коротко',
    live: 'ЖИВЫЕ ЗАДАЧИ',
    liveHint: 'Читается с доски на Railway в момент просмотра; не входит в запечатанный .t27.',
    liveDown: 'Живая доска сейчас недоступна с этой страницы.',
    liveLoading: 'читаю живую доску…',
    liveOpen: 'ОТКРЫТЬ ЖИВУЮ ДОСКУ',
    levers: 'РЫЧАГИ МАСКИ, A/B',
    leversHint: 'Каждое правило маски — парное плечо на тех же задачах и движке, проверенное на двух seed генерации. Вердикт — объединённый точный тест Макнемара по расхождениям compile.',
    lever: 'рычаг',
    seed: 'seed',
    compile: 'compile',
    pooled: 'вместе',
    discord: 'только base / только arm',
    verdict: 'вердикт',
    pass: 'pass',
    pending: 'ещё не забрано',
    arena: 'АРЕНА ОТБОРА',
    arenaHint: 'Checkpoint проходят ворота по порядку; негативный контроль обязан провалиться. Числа арены сравниваются только внутри одного прогона.',
    candidate: 'кандидат',
    gates: 'ворота',
    strict: 'strict pass',
    toks: 'ток/с',
    bpb: 'bpb',
    rank: 'место',
    decision: 'решение арены',
    pipeline: 'КОНВЕЙЕР',
    roadmap: 'ДОРОЖНАЯ КАРТА',
    judge: 'судья',
    model: 'МОДЕЛЬ',
    sealed: 'запечатано из',
    snapshot: 'снимок',
  },
} as const

const HEADLINE_RU: Record<string, string> = {
  strict_pass: 'strict pass',
  compile: 'компилируется',
  clean_set: 'чистый набор',
  diff_kills: 'убито diff-судьёй',
  with_args_wrong: 'ложные pass с аргументами',
  params: 'параметров',
  val_bpb: 'val bpb',
}

const VERDICT_RU: Record<string, string> = {
  kept: 'оставлен',
  'no-effect': 'нет эффекта',
  harmful: 'вредит',
  pending: 'ждёт',
}

const STATE_RU: Record<string, string> = { done: 'готово', next: 'дальше', blocked: 'заблокировано', running: 'идёт' }

const POLL_MS = 30_000

function Evidence({ value }: { value: string }) {
  return <span className="queen-wars-evidence" data-evidence={value}>{value}</span>
}

function leverOutcome(verdict: string) {
  if (verdict === 'kept') return 'positive'
  if (verdict === 'harmful') return 'blocked'
  if (verdict === 'pending') return 'running'
  return 'neutral'
}

function stateOutcome(state: string) {
  if (state === 'done') return 'positive'
  if (state === 'blocked') return 'blocked'
  if (state === 'running') return 'running'
  return 'neutral'
}

function gateOutcome(value: string) {
  return value === 'pass' ? 'positive' : value === 'fail' ? 'blocked' : 'neutral'
}

function hhmm(iso: string | undefined) {
  return iso ? iso.replace('T', ' ').slice(0, 16) + 'Z' : ''
}

// The live board repeats a job's last line as a heartbeat, so the strip shows
// the newest line per job, newest jobs first.
function newestPerJob(events: LiveEvent[], live: Record<string, LiveEvent>) {
  const byJob = new Map<string, LiveEvent>()
  for (const event of [...Object.values(live), ...events]) {
    if (!event?.job || typeof event.msg !== 'string') continue
    const seen = byJob.get(event.job)
    if (!seen || (event.rx ?? '') >= (seen.rx ?? '')) byJob.set(event.job, event)
  }
  return [...byJob.values()].sort((a, b) => (b.rx ?? '').localeCompare(a.rx ?? '')).slice(0, 4)
}

function useLiveState(): LiveState {
  const [live, setLive] = useState<LiveState>({ status: 'loading' })
  useEffect(() => {
    let cancelled = false
    // The first read always runs; later ticks skip a hidden tab.
    const read = async (tick: boolean) => {
      if (tick && document.hidden) return
      try {
        const response = await fetch(IGLA_BOARD.live.state, { cache: 'no-store', credentials: 'omit' })
        if (!response.ok) throw new Error(String(response.status))
        const data = await response.json() as { events?: LiveEvent[], live?: Record<string, LiveEvent>, server_time?: string }
        if (!cancelled) setLive({ status: 'ok', jobs: newestPerJob(data.events ?? [], data.live ?? {}), serverTime: data.server_time ?? '' })
      } catch {
        if (!cancelled) setLive({ status: 'down' })
      }
    }
    read(false)
    const timer = window.setInterval(() => read(true), POLL_MS)
    return () => { cancelled = true; window.clearInterval(timer) }
  }, [])
  return live
}

export function IglaBoard({ lang }: { lang: 'en' | 'ru' }) {
  const c = COPY[lang]
  const live = useLiveState()
  const verdict = (value: string) => lang === 'ru' ? (VERDICT_RU[value] ?? value) : value
  const state = (value: string) => lang === 'ru' ? (STATE_RU[value] ?? value) : value
  const gateKeys = IGLA_BOARD.gates.map((gate) => gate.key)

  return (
    <section className="igla-board" id="igla-board" aria-labelledby="igla-board-title">
      <header className="igla-board-head">
        <div>
          <p className="igla-board-kicker">{c.kicker}</p>
          <h2 id="igla-board-title"><span aria-hidden="true">◈</span> {c.title}</h2>
          <p>{c.lead}</p>
        </div>
        <nav className="igla-board-links" aria-label={c.title}>
          <a className="queen-wars-source" href="queen/igla-board.t27">
            <span>{c.source}</span>
            <code>{IGLA_BOARD.source.sha256.slice(0, 16)}</code>
          </a>
          <a className="queen-wars-source" href={IGLA_BOARD.model} rel="noopener noreferrer">
            <span>{c.model}</span>
            <code>tern-tc-9m-t27</code>
          </a>
        </nav>
      </header>

      <section className="igla-board-glance" aria-label={c.glance}>
        <dl>
          {IGLA_BOARD.headline.map((item) => (
            <div key={item.key}>
              <dd>{item.value}{item.of !== null && <small>/{item.of}</small>}</dd>
              <dt>{lang === 'ru' ? (HEADLINE_RU[item.key] ?? item.label) : item.label}</dt>
              <p>{item.hint}</p>
            </div>
          ))}
        </dl>
        <p className="igla-board-judge"><strong>{c.judge}:</strong> {IGLA_BOARD.judge}</p>
      </section>

      <section className="igla-board-live" aria-labelledby="igla-board-live-title" aria-live="polite">
        <header className="queen-wars-section-title">
          <span>01</span>
          <h3 id="igla-board-live-title">{c.live}</h3>
          <Evidence value={live.status === 'ok' ? 'SESSION-OBSERVED' : 'UNKNOWN'} />
        </header>
        <p className="igla-board-hint">{c.liveHint}</p>
        {live.status === 'loading' && <p className="igla-board-empty">{c.liveLoading}</p>}
        {live.status === 'down' && <p className="igla-board-empty">{c.liveDown}</p>}
        {live.status === 'ok' && (
          <ol className="igla-board-jobs">
            {live.jobs.map((job) => {
              const progress = typeof job.progress === 'number' ? Math.max(0, Math.min(1, job.progress)) : null
              return (
                <li key={job.job} data-outcome={progress === 1 ? 'positive' : progress !== null ? 'running' : 'neutral'}>
                  <code>{job.job}</code>
                  <span>{job.msg}</span>
                  <time dateTime={job.rx}>{hhmm(job.rx)}</time>
                  {progress !== null && <i className="igla-board-progress" style={{ '--bar': progress.toFixed(3) } as CSSProperties} aria-hidden="true" />}
                </li>
              )
            })}
          </ol>
        )}
        <a className="igla-board-cta" href={IGLA_BOARD.live.board} rel="noopener noreferrer">{c.liveOpen} →</a>
      </section>

      <section className="igla-board-levers" aria-labelledby="igla-board-levers-title">
        <header className="queen-wars-section-title">
          <span>02</span>
          <h3 id="igla-board-levers-title">{c.levers}</h3>
        </header>
        <p className="igla-board-hint">{c.leversHint}</p>
        <div className="queen-wars-table-scroll" tabIndex={0} role="region" aria-label={c.levers}>
          <table data-stack="">
            <thead>
              <tr>
                <th scope="col">{c.lever}</th>
                {IGLA_BOARD.levers[0].pairs.map((pair) => <th scope="col" key={pair.seed}>{c.seed} {pair.seed} · {c.compile}</th>)}
                <th scope="col">{c.pooled} · {c.discord}</th>
                <th scope="col">{c.verdict}</th>
              </tr>
            </thead>
            <tbody>
              {IGLA_BOARD.levers.map((lever) => (
                <tr key={lever.id}>
                  <th scope="row"><code>{lever.id}</code><small>{lever.change}</small></th>
                  {lever.pairs.map((pair) => (
                    <td key={pair.seed} data-label={`${c.seed} ${pair.seed} · ${c.compile}`}>
                      {pair.armCompile === null ? <><span>{c.pending}</span><Evidence value="UNKNOWN" /></> : <>
                        <strong>{pair.baseCompile} → {pair.armCompile}</strong>
                        <small>p {pair.p} · {c.pass} {pair.basePass} → {pair.armPass}</small>
                      </>}
                    </td>
                  ))}
                  <td data-label={`${c.pooled} · ${c.discord}`}>{lever.p === null ? '—' : <><strong>{lever.onlyBase} / {lever.onlyArm}</strong><small>p {lever.p}</small></>}</td>
                  <td data-label={c.verdict} data-outcome={leverOutcome(lever.verdict)}><strong>{verdict(lever.verdict)}</strong><Evidence value={lever.evidence} /></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="igla-board-arena" aria-labelledby="igla-board-arena-title">
        <header className="queen-wars-section-title">
          <span>03</span>
          <h3 id="igla-board-arena-title">{c.arena}</h3>
        </header>
        <p className="igla-board-hint">{c.arenaHint}</p>
        <div className="queen-wars-table-scroll" tabIndex={0} role="region" aria-label={c.arena}>
          <table data-stack="">
            <thead>
              <tr>
                <th scope="col">{c.candidate}</th>
                <th scope="col">{c.gates}</th>
                <th scope="col">{c.compile}</th>
                <th scope="col">{c.strict}</th>
                <th scope="col">{c.toks}</th>
                <th scope="col">{c.bpb}</th>
                <th scope="col">{c.verdict}</th>
              </tr>
            </thead>
            <tbody>
              {IGLA_BOARD.candidates.map((candidate) => (
                <tr key={candidate.id}>
                  <th scope="row"><code>{candidate.id}</code><small>{candidate.format} · {candidate.sha}</small></th>
                  <td data-label={c.gates}>
                    <ul className="igla-board-gates">
                      {gateKeys.map((key) => {
                        const value = (candidate.gates as Record<string, string>)[key] ?? 'pending'
                        return <li key={key} data-outcome={gateOutcome(value)}>{key}</li>
                      })}
                    </ul>
                  </td>
                  <td data-label={c.compile}>{candidate.compile ?? '—'}</td>
                  <td data-label={c.strict}>{candidate.strictPass ?? '—'}</td>
                  <td data-label={c.toks}>{candidate.tokS ?? '—'}</td>
                  <td data-label={c.bpb}>{candidate.bpb ?? '—'}</td>
                  <td data-label={c.verdict} data-outcome={candidate.rank ? 'positive' : 'blocked'}>
                    <strong>{candidate.rank ? `#${candidate.rank} ` : ''}{candidate.verdict}</strong>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <details className="igla-board-details">
          <summary>{c.decision}</summary>
          <p>{IGLA_BOARD.arenaDecision}</p>
          <dl>
            {IGLA_BOARD.gates.map((gate) => <div key={gate.key}><dt>{gate.key}</dt><dd>{gate.rule}</dd></div>)}
          </dl>
        </details>
      </section>

      <section className="igla-board-pipeline" aria-labelledby="igla-board-pipeline-title">
        <header className="queen-wars-section-title">
          <span>04</span>
          <h3 id="igla-board-pipeline-title">{c.pipeline}</h3>
        </header>
        <ol className="igla-board-stages">
          {IGLA_BOARD.stages.map((stage) => (
            <li key={stage.id} data-outcome={stateOutcome(stage.state)}>
              <strong>{stage.title}</strong>
              <span className="igla-board-state">{state(stage.state)}</span>
              {stage.metric && <code>{stage.metric}</code>}
              <small>{stage.detail}</small>
            </li>
          ))}
        </ol>
      </section>

      <section className="igla-board-roadmap" aria-labelledby="igla-board-roadmap-title">
        <header className="queen-wars-section-title">
          <span>05</span>
          <h3 id="igla-board-roadmap-title">{c.roadmap}</h3>
        </header>
        <ol>
          {IGLA_BOARD.roadmap.map((item, index) => (
            <li key={`${item.when}-${index}`} data-outcome={stateOutcome(item.state)}>
              <time>{item.when}</time>
              <strong>{item.title}</strong>
              {item.result && <small>{item.result}</small>}
            </li>
          ))}
        </ol>
      </section>

      <footer className="igla-board-foot">
        <span>{c.sealed}</span>
        <code>{IGLA_BOARD.source.repo}@{IGLA_BOARD.source.commit.slice(0, 12)}</code>
        <span>{c.snapshot}</span>
        <code>{IGLA_BOARD.source.snapshotAt}</code>
      </footer>
    </section>
  )
}
