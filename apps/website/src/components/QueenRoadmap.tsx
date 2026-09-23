// ROADMAP: the game's goal, measured. Everything below the interface in .t27,
// generated to its target (trios CLAUDE.md, law L0) - and how far the stack
// that runs app.t27.ai is from that today, repository by repository and
// language by language.
//
// Two files feed it. public/roadmap/stack.json is a COUNT (scripts/
// roadmap-stack.mjs: tracked files at a named commit, bytes of source), and
// public/roadmap/goals.json is the PLAN: one stage per rewrite, each a goal
// issue in gHashTag/t27 labelled `roadmap`. The issue's state is read live from
// GitHub, so a stage the swarm closes shows closed here without a deploy; if
// GitHub does not answer, the stage says "state unknown" rather than guessing.

import { useEffect, useMemo, useState } from 'react'
import './queenRoadmap.css'

type LangCount = { files: number; bytes: number }
interface StackRepo {
  repo: string
  sub: string | null
  role: string
  commit: string
  languages: Record<string, LangCount>
}
interface Stack {
  measuredAt: string
  method: string
  repos: StackRepo[]
  totals: Record<string, LangCount>
}
interface Goal {
  id: string
  stage: number
  title: { en: string; ru: string }
  why: { en: string; ru: string }
  repos: string[]
  languages: string[]
  target: string
  issue: number | null
  /** A GitHub issue search whose closed share is this stage's progress. */
  progress?: string
}
interface Goals {
  issueRepo: string
  goals: Goal[]
}
type IssueState = 'open' | 'closed'

// Languages nobody rewrites: configuration and container recipes are data,
// not logic, and stay what they are.
const NOT_A_TARGET = new Set(['Config', 'Docker', 'Make'])

const COLOR: Record<string, string> = {
  T27: '#00ff88',
  TypeScript: '#3178c6',
  JavaScript: '#f1e05a',
  Python: '#4b8bbe',
  Rust: '#dea584',
  Zig: '#ec915c',
  Swift: '#f05138',
  Go: '#00add8',
  Gleam: '#ffaff3',
  Shell: '#89e051',
  CSS: '#8f6fd8',
  HTML: '#e34c26',
  SQL: '#e38c00',
  C: '#a8b9cc',
  'C++': '#f34b7d',
  Verilog: '#b2b7f8',
  Erlang: '#b83998',
  Elixir: '#6e4a7e',
  Kotlin: '#a97bff',
  Docker: '#5a7d8c',
  Make: '#6d8a5f',
  Config: '#56606a',
}
const colorOf = (lang: string) => COLOR[lang] ?? '#7a7f86'

const COPY = {
  en: {
    title: 'ROADMAP',
    goal: 'The game: rewrite the whole stack in .t27',
    goalBody:
      'Everything below the interface is written once, in .t27, and generated to its target - Rust for servers, Zig, C and Verilog for the core and silicon. The one exception is the seed: t27c itself stays hand-written Rust. This tab counts how far the code that runs app.t27.ai is from that, and the plan to close it.',
    share: 'of the stack is .t27 today',
    toPort: 'still to rewrite',
    inT27: 'already in .t27',
    ported: 'port issues closed',
    other: 'other',
    languages: 'By language',
    repos: 'By repository',
    stages: 'The plan: one goal per stage',
    measured: 'Measured',
    method: 'How',
    stateOpen: 'open',
    stateClosed: 'done',
    stateNone: 'no issue yet',
    stateUnknown: 'state unknown',
    target: 'target',
    loading: 'Reading the count…',
    failed: 'The count could not be read.',
    joinTitle: 'The rewrite is one file at a time. Take one.',
    joinBody:
      'Nobody rewrites a stack in one commit. Each stage is cut into issues of one file each, and every closed one moves the number above. You do not need permission and you do not need to know .t27 first: the issue names the file, the boundary says what it may touch, and the Queen reviews what comes back.',
    joinOpen: 'port issues open right now',
    joinBrowse: 'Browse the open issues',
    joinLend: 'Or lend the swarm a lane',
    joinLendBody:
      'No time to write code? A bee runs on somebody’s provider API key. Lend one and its work earns you XP on the leaderboard — several providers give a key away for nothing.',
    joinLearn: 'How to join, step by step',
  },
  ru: {
    title: 'ДОРОЖНАЯ КАРТА',
    goal: 'Игра: переписать весь стек на .t27',
    goalBody:
      'Всё ниже интерфейса пишется один раз, на .t27, и генерируется в свою цель — Rust для серверов, Zig, C и Verilog для ядра и кремния. Единственное исключение — зерно: сам t27c остаётся рукописным Rust. Эта вкладка считает, насколько код, на котором работает app.t27.ai, далёк от этого, и показывает план, как дойти.',
    share: 'стека уже на .t27',
    toPort: 'ещё переписать',
    inT27: 'уже на .t27',
    ported: 'задач переноса закрыто',
    other: 'прочие',
    languages: 'По языкам',
    repos: 'По репозиториям',
    stages: 'План: одна цель на этап',
    measured: 'Измерено',
    method: 'Как',
    stateOpen: 'в работе',
    stateClosed: 'готово',
    stateNone: 'задачи ещё нет',
    stateUnknown: 'состояние неизвестно',
    target: 'цель',
    loading: 'Читаю подсчёт…',
    failed: 'Подсчёт прочитать не удалось.',
    joinTitle: 'Переписывание идёт по одному файлу. Возьмите один.',
    joinBody:
      'Никто не переписывает стек одним коммитом. Каждый этап нарезан на задачи по одному файлу, и каждая закрытая двигает число выше. Разрешения не нужно, и знать .t27 заранее тоже: в задаче назван файл, границы говорят, что можно трогать, а Королева проверяет то, что вернулось.',
    joinOpen: 'задач переноса открыто прямо сейчас',
    joinBrowse: 'Посмотреть открытые задачи',
    joinLend: 'Или дайте рою полосу',
    joinLendBody:
      'Нет времени писать код? Пчела работает на чьём-то API-ключе провайдера. Одолжите свой — и его работа принесёт вам XP в лидерборде; несколько провайдеров выдают ключ бесплатно.',
    joinLearn: 'Как присоединиться, по шагам',
  },
} as const

/** A size in the unit people read: MB above a megabyte, KB below. */
const size = (bytes: number) =>
  bytes >= 1e6 ? `${(bytes / 1e6).toFixed(bytes >= 1e7 ? 0 : 1)} MB` : `${Math.max(1, Math.round(bytes / 1e3))} KB`
const pct = (part: number, whole: number) =>
  whole > 0 ? `${((100 * part) / whole).toFixed(part / whole < 0.1 ? 1 : 0)}%` : '0%'

/** Bytes of real code (config excluded), sorted largest first. */
function codeLanguages(langs: Record<string, LangCount>): Array<[string, LangCount]> {
  return Object.entries(langs)
    .filter(([lang]) => !NOT_A_TARGET.has(lang))
    .sort((a, b) => b[1].bytes - a[1].bytes)
}

/** The ten largest languages, and the rest as one line: 25 rows of 0.0% said nothing. */
function legendOf(code: Array<[string, LangCount]>, other: string): Array<[string, LangCount]> {
  if (code.length <= 11) return code
  const rest = code.slice(10).reduce(
    (sum, [, v]) => ({ files: sum.files + v.files, bytes: sum.bytes + v.bytes }),
    { files: 0, bytes: 0 },
  )
  return [...code.slice(0, 10), [`${other} (${code.length - 10})`, rest]]
}

function StackedBar({
  parts,
  total,
  height = 14,
}: {
  parts: Array<[string, number]>
  total: number
  height?: number
}) {
  // Offsets computed before render: a running total mutated inside map() is
  // a value changed after render as far as React's rules are concerned.
  const widths = parts.map(([, bytes]) => (total > 0 ? (1000 * bytes) / total : 0))
  const offsets = widths.map((_, i) => widths.slice(0, i).reduce((a, b) => a + b, 0))
  return (
    // Sized by the div, not the svg: the board styles every svg inside its
    // viewport, and an svg given only its own height drew at 0 px there.
    <div className="rm-bar" style={{ height }}>
      <svg viewBox="0 0 1000 10" preserveAspectRatio="none" width="100%" height="100%" role="img">
        {parts.map(([lang, bytes], i) => (
          <rect key={lang} x={offsets[i]} y={0} width={Math.max(widths[i], 0)} height={10} fill={colorOf(lang)}>
            <title>{`${lang}: ${size(bytes)}`}</title>
          </rect>
        ))}
      </svg>
    </div>
  )
}

export default function QueenRoadmap({ lang }: { lang: 'en' | 'ru' }) {
  const c = lang === 'ru' ? COPY.ru : COPY.en
  const [stack, setStack] = useState<Stack | null | 'failed'>(null)
  const [goals, setGoals] = useState<Goals | null>(null)
  const [states, setStates] = useState<Record<number, IssueState> | null>(null)
  const [progress, setProgress] = useState<Record<string, { done: number; all: number }>>({})

  useEffect(() => {
    let live = true
    Promise.all([
      fetch('roadmap/stack.json', { credentials: 'omit' }).then((r) => (r.ok ? r.json() : Promise.reject(r.status))),
      fetch('roadmap/goals.json', { credentials: 'omit' }).then((r) => (r.ok ? r.json() : Promise.reject(r.status))),
    ])
      .then(([s, g]: [Stack, Goals]) => {
        if (!live) return
        setStack(s)
        setGoals(g)
        // Live state of the goal issues; one anonymous request, and a failure
        // leaves every stage saying its state is unknown.
        fetch(
          `https://api.github.com/repos/${g.issueRepo}/issues?labels=roadmap&state=all&per_page=100`,
          { credentials: 'omit' },
        )
          .then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
          .then((rows: Array<{ number: number; state: IssueState; pull_request?: unknown }>) => {
            if (!live) return
            const map: Record<number, IssueState> = {}
            for (const row of rows) if (!row.pull_request) map[row.number] = row.state
            setStates(map)
          })
          .catch(() => {})
        // A stage worked as one issue per file shows how many are closed: two
        // searches per such stage, and a failure just leaves the bar out.
        for (const goal of g.goals) {
          if (!goal.progress) continue
          const count = (q: string) =>
            fetch(`https://api.github.com/search/issues?per_page=1&q=${encodeURIComponent(q)}`, { credentials: 'omit' })
              .then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
              .then((j: { total_count: number }) => j.total_count)
          Promise.all([count(goal.progress), count(`${goal.progress} is:closed`)])
            .then(([all, done]) => live && setProgress((p) => ({ ...p, [goal.id]: { done, all } })))
            .catch(() => {})
        }
      })
      .catch(() => live && setStack('failed'))
    return () => {
      live = false
    }
  }, [])

  const summary = useMemo(() => {
    if (!stack || stack === 'failed') return null
    const code = codeLanguages(stack.totals)
    const total = code.reduce((n, [, v]) => n + v.bytes, 0)
    const t27 = stack.totals.T27?.bytes ?? 0
    return { code, total, t27 }
  }, [stack])

  const repoLines = (repo: StackRepo) =>
    codeLanguages(repo.languages).reduce((n, [, v]) => n + v.bytes, 0)

  const goalLines = (goal: Goal): number => {
    if (!stack || stack === 'failed') return 0
    let n = 0
    for (const r of stack.repos) {
      if (!goal.repos.includes(r.repo)) continue
      for (const l of goal.languages) n += r.languages[l]?.bytes ?? 0
    }
    return n
  }

  if (stack === null) return <section className="rm"><p className="rm-note">{c.loading}</p></section>
  if (stack === 'failed' || !summary) return <section className="rm"><p className="rm-note">{c.failed}</p></section>

  const maxRepo = Math.max(...stack.repos.map(repoLines), 1)

  return (
    <section className="rm" aria-label={c.title}>
      <header className="rm-hero">
        <div className="rm-hero-text">
          <h2>{c.goal}</h2>
          <p>{c.goalBody}</p>
        </div>
        <div className="rm-dial" aria-label={`${pct(summary.t27, summary.total)} ${c.share}`}>
          <svg viewBox="0 0 120 120">
            <circle cx="60" cy="60" r="50" className="rm-dial-track" />
            <circle
              cx="60"
              cy="60"
              r="50"
              className="rm-dial-fill"
              strokeDasharray={`${(314.16 * summary.t27) / Math.max(summary.total, 1)} 314.16`}
            />
          </svg>
          <div className="rm-dial-num">
            <strong>{pct(summary.t27, summary.total)}</strong>
            <span>{c.share}</span>
          </div>
        </div>
      </header>

      <div className="rm-kpis">
        <div><strong>{size(summary.t27)}</strong><span>{c.inT27}</span></div>
        <div><strong>{size(summary.total - summary.t27)}</strong><span>{c.toPort}</span></div>
        <div><strong>{stack.repos.length}</strong><span>repos</span></div>
        <div><strong>{summary.code.length}</strong><span>{lang === 'ru' ? 'языков' : 'languages'}</span></div>
      </div>

      {/* THE INVITATION. A measurement is not a reason for a stranger to stay:
          this tab said how far the rewrite has to go and never said that
          anyone could push it. The count of open issues is the one already
          fetched for the stage bars, so this costs no extra request, and it
          links the real GitHub search rather than a page about the project. */}
      {goals && (
        <aside className="rm-join">
          <h3>{c.joinTitle}</h3>
          <p>{c.joinBody}</p>
          <div className="rm-join-acts">
            {(() => {
              const staged = goals.goals.find((g) => g.progress && progress[g.id])
              const bar = staged ? progress[staged.id] : undefined
              const open = bar ? Math.max(0, bar.all - bar.done) : null
              const query = staged?.progress ? `${staged.progress} is:open` : ''
              return (
                <a
                  className="rm-join-cta"
                  href={
                    query
                      ? `https://github.com/${goals.issueRepo}/issues?q=${encodeURIComponent(query)}`
                      : `https://github.com/${goals.issueRepo}/issues`
                  }
                  target="_blank"
                  rel="noreferrer noopener"
                >
                  {open !== null && <strong>{open}</strong>}
                  <span>{open !== null ? c.joinOpen : c.joinBrowse}</span>
                </a>
              )
            })()}
            <a
              className="rm-join-link"
              href={`https://github.com/${goals.issueRepo}/blob/master/docs/JOIN.md`}
              target="_blank"
              rel="noreferrer noopener"
            >
              {c.joinLearn} →
            </a>
          </div>
          <p className="rm-join-lend">
            <b>{c.joinLend}.</b> {c.joinLendBody}
          </p>
        </aside>
      )}

      <h3>{c.languages}</h3>
      <StackedBar parts={summary.code.map(([l, v]) => [l, v.bytes])} total={summary.total} height={22} />
      <ul className="rm-legend">
        {legendOf(summary.code, c.other).map(([l, v]) => (
          <li key={l}>
            <i style={{ background: colorOf(l) }} />
            <b>{l}</b>
            <span>{size(v.bytes)} · {pct(v.bytes, summary.total)}</span>
          </li>
        ))}
      </ul>

      <h3>{c.repos}</h3>
      <ul className="rm-repos">
        {stack.repos
          .slice()
          .sort((a, b) => repoLines(b) - repoLines(a))
          .map((r) => {
            const lines = repoLines(r)
            const t27 = r.languages.T27?.bytes ?? 0
            return (
              <li key={r.repo}>
                <div className="rm-repo-head">
                  <a href={`https://github.com/${r.repo}${r.sub ? `/tree/${r.commit}/${r.sub}` : ''}`} target="_blank" rel="noreferrer">
                    {r.repo.replace('gHashTag/', '')}{r.sub ? `/${r.sub}` : ''}
                  </a>
                  <span>{size(lines)} · T27 {pct(t27, lines)}</span>
                </div>
                <div className="rm-repo-bar" style={{ width: `${Math.max((100 * lines) / maxRepo, 2)}%` }}>
                  <StackedBar parts={codeLanguages(r.languages).map(([l, v]) => [l, v.bytes])} total={lines} />
                </div>
                <p>{r.role}</p>
              </li>
            )
          })}
      </ul>

      {goals && (
        <>
          <h3>{c.stages}</h3>
          <ol className="rm-stages">
            {goals.goals
              .slice()
              .sort((a, b) => a.stage - b.stage)
              .map((g) => {
                const state: string =
                  g.issue === null
                    ? c.stateNone
                    : states === null
                      ? c.stateUnknown
                      : states[g.issue] === 'closed'
                        ? c.stateClosed
                        : states[g.issue] === 'open'
                          ? c.stateOpen
                          : c.stateUnknown
                const done = g.issue !== null && states?.[g.issue] === 'closed'
                return (
                  <li key={g.id} className={done ? 'rm-done' : ''}>
                    <div className="rm-stage-num">{g.stage}</div>
                    <div className="rm-stage-body">
                      <div className="rm-stage-head">
                        <b>{g.title[lang]}</b>
                        {g.issue !== null ? (
                          <a href={`https://github.com/${goals.issueRepo}/issues/${g.issue}`} target="_blank" rel="noreferrer" className="rm-chip">
                            #{g.issue} · {state}
                          </a>
                        ) : (
                          <span className="rm-chip">{state}</span>
                        )}
                      </div>
                      <p>{g.why[lang]}</p>
                      {progress[g.id] && progress[g.id].all > 0 && (
                        <div className="rm-progress">
                          <div className="rm-progress-track">
                            <div style={{ width: `${(100 * progress[g.id].done) / progress[g.id].all}%` }} />
                          </div>
                          <span>
                            {progress[g.id].done} / {progress[g.id].all} {c.ported}
                          </span>
                        </div>
                      )}
                      <div className="rm-stage-meta">
                        {g.languages.map((l) => (
                          <span key={l} className="rm-lang"><i style={{ background: colorOf(l) }} />{l}</span>
                        ))}
                        <span>→ {c.target}: {g.target}</span>
                        <span>{size(goalLines(g))}</span>
                      </div>
                    </div>
                  </li>
                )
              })}
          </ol>
        </>
      )}

      <footer className="rm-foot">
        <p>
          {c.measured}: {new Date(stack.measuredAt).toISOString().slice(0, 10)} ·{' '}
          {stack.repos.map((r) => `${r.repo.replace('gHashTag/', '')}@${r.commit.slice(0, 7)}`).join(', ')}
        </p>
        <p>{c.method}: {stack.method}</p>
      </footer>
    </section>
  )
}
