// LEVEL II: the rewrite, as the game it is.
//
// The ROADMAP tab measured the goal - bytes per language, a dial, eight stage
// cards - and never showed anyone PLAYING it. This is the board of that game:
//
//   * THE COMB is an inverted pyramid, apex down, the shape of the t27 mark.
//     The apex is the seed (t27c, the one hand-written thing everything else is
//     generated from). Every other cell is one port task - one file of the
//     stack becoming .t27 - and the cells are laid from the apex upward in the
//     order the swarm should take them: the quickest first (fewest functions),
//     so the comb is built from its point outward, the way the feeder files
//     work. The widest row is the summit: the whole stack, and in the end the
//     browser and every dependency we run, in .t27.
//   * A BEE AT WORK is a ship over its cell with a beam into it. Only what the
//     Queen's own board says is running is drawn as a ship; the page invents no
//     activity, and when the board does not answer it draws no ships and says so.
//   * THE QUEEN'S ROUND is a band of light that climbs the comb from the apex,
//     timed by the board's own pulse (lastRoundAt, roundSeconds).
//   * A CRACKED CELL is a built file with an open defect filed against it: the
//     cell stays built and shows the crack until the defect closes.
//   * THE RAID moves to another sector every UTC midnight; the roadmap feeder
//     files that sector's tasks first the same day (gHashTag/t27
//     tools/queen/feed_roadmap.py, RAID_STAGES), and its cells built today
//     count double HONEY - the board's own score, the functions ported.
//   * BOSSES are stage 8 (the interface decision) and the endgame. Their HP is
//     the measured source still to rewrite; a fight opens when half the comb
//     below is built, and each says what really stands in the way.
//   * BUILDERS are the lenders whose lanes built .t27 cells, read from the
//     Queen's public leaderboard; XP is hers, never recomputed here.
//
// Sources, all live and all public: GitHub issue search (port tasks open and
// closed as completed, and open defects naming a port file), the Queen's
// /queen/public-board and /queen/public-leaderboard. A source that does not
// answer is named on the page, and what it would have fed reads as unknown.

import { useEffect, useMemo, useState } from 'react'
import { QUEEN_API } from '../lib/queenApi'
import {
  BOSS_OPENS_AT,
  builtShareBelow,
  crackedTargets,
  honeyOf,
  msToNextDay,
  parsePortTitle,
  pulsePhase,
  raidOf,
  rowsFor,
  targetOf,
  utcDay,
} from '../lib/roadmapGame'
import './queenRoadmapGame.css'

export interface GameGoal {
  id: string
  stage: number
  title: { en: string; ru: string }
  repos: string[]
  languages: string[]
  issue: number | null
  locked?: { en: string; ru: string }
}

type CellState = 'seed' | 'built' | 'cracked' | 'review' | 'building' | 'held' | 'target' | 'future'

interface PortTask {
  number: number
  title: string
  repo: string
  path: string
  lang: string
  units: number
  stage: number | null
  state: CellState
  closedAt: string | null
}

interface Builder {
  name: string
  claimed: boolean
  specs: number
  xp: number
}

const MARK = '#08fab5'

const LANG_COLOR: Record<string, string> = {
  Python: '#4b8bbe',
  Shell: '#89e051',
  TypeScript: '#3178c6',
  JavaScript: '#f1e05a',
  Go: '#00add8',
  Rust: '#dea584',
  Zig: '#ec915c',
  C: '#a8b9cc',
  Verilog: '#b2b7f8',
  Gleam: '#ffaff3',
}

const COPY = {
  en: {
    level: 'LEVEL II · THE REWRITE',
    title: 'The comb is built from its point up',
    lead:
      'Every cell is one file of the stack becoming .t27. The point at the bottom is the seed, t27c; the bees build upward from the quickest tasks, row by row, to the widest row: the whole stack in .t27, and in the end the browser and every dependency we run.',
    summit: 'Top row: the whole stack in .t27, the BrowserOS browser and every dependency included',
    seed: 'The point: the seed, t27c, the one hand-written thing',
    quick: 'quickest tasks first',
    built: 'built',
    cracked: 'cracked: a defect is open against it',
    review: 'waiting for the Queen',
    building: 'a bee is building',
    held: 'files held',
    target: 'target, free',
    future: 'not filed yet',
    raidCell: 'raid sector',
    hudBuilt: 'cells built',
    hudHoney: 'honey',
    hudHoneyHint:
      'Honey is this board’s own score: the functions ported in built cells, with raid-sector cells built today counted twice. The Queen’s XP is on the leaderboard.',
    hudBuilding: 'bees building now',
    hudTargets: 'free targets',
    hudCracked: 'cracked cells',
    hudRow: 'highest row reached',
    raid: 'Raid of the day',
    raidBody: (title: string) =>
      `Sector ${title}. The roadmap feeder files its tasks first today, and its cells built today give double honey.`,
    raidEnds: (h: number, m: number) => `The raid moves at UTC midnight, in ${h} h ${m} min.`,
    raidNone: 'No sector can be raided: every stage below the bosses is locked.',
    round: (sec: number, left: number) => `The Queen’s round: every ${sec} s, the next in ${left} s. The band of light is her round climbing the comb.`,
    roundNone: 'The Queen’s round is not known: the board gave no pulse.',
    targets: 'Priority targets: the quickest free cells',
    targetsNone: 'No free port task right now. The roadmap feeder files the next ones every hour.',
    attack: 'take it',
    fn: 'fn',
    sectors: 'Sectors',
    captured: 'captured',
    underAttack: 'under attack',
    openFront: 'open front',
    noTasks: 'no tasks filed yet',
    locked: 'locked',
    inFlight: 'in flight',
    free: 'free',
    unknown: 'unknown: GitHub did not answer',
    raidTag: 'raid',
    bosses: 'Bosses',
    bossHp: 'HP: source still to rewrite',
    bossHpUnknown: 'HP: not measured yet',
    bossOpens: (pct: number) =>
      `The fight opens when ${Math.round(BOSS_OPENS_AT * 100)}% of the comb below is built (this board’s rule). Built now: ${pct}%.`,
    bossOpen: 'The fight is open: half the comb below is built.',
    bossWhy: 'What really stands in the way:',
    builders: 'Builders: whose lanes built .t27 cells',
    buildersBody: 'From the Queen’s public leaderboard: accepted issues whose boundary named a .t27 file, and her XP.',
    buildersNone: 'No lane has built a .t27 cell yet.',
    buildersDown: 'The Queen’s leaderboard did not answer.',
    cells: 'cells',
    unclaimed: 'unclaimed lane',
    boardDown: "The Queen's board did not answer, so no ship is drawn: a ship is only what the board reports running.",
    githubDown: 'GitHub did not answer the task search, so the comb shows only the seed and the frame.',
    loading: 'Reading the comb…',
    ships: 'Ships over the comb right now',
    shipsNone: 'No bee is building a port cell right now.',
    legend: 'Legend',
  },
  ru: {
    level: 'УРОВЕНЬ II · ПЕРЕПИСЫВАНИЕ',
    title: 'Соты строятся от вершины вверх',
    lead:
      'Каждая сота — один файл стека, который становится .t27. Вершина внизу — зерно, t27c; пчёлы строят вверх от самых быстрых задач, ряд за рядом, до самого широкого ряда: весь стек на .t27, а в итоге и браузер, и каждая сторонняя зависимость, которой мы пользуемся.',
    summit: 'Верхний ряд: весь стек на .t27, включая браузер BrowserOS и каждую зависимость',
    seed: 'Вершина: зерно t27c, единственное рукописное',
    quick: 'сначала самые быстрые задачи',
    built: 'построено',
    cracked: 'трещина: против неё открыт дефект',
    review: 'ждёт Королеву',
    building: 'пчела строит',
    held: 'файлы заняты',
    target: 'цель, свободна',
    future: 'ещё не заведено',
    raidCell: 'сектор рейда',
    hudBuilt: 'сот построено',
    hudHoney: 'мёд',
    hudHoneyHint:
      'Мёд — собственный счёт этой доски: функции, перенесённые в построенных сотах; соты сектора рейда, построенные сегодня, считаются дважды. XP Королевы — в лидерборде.',
    hudBuilding: 'пчёл строят сейчас',
    hudTargets: 'свободных целей',
    hudCracked: 'сот с трещиной',
    hudRow: 'самый высокий ряд',
    raid: 'Рейд дня',
    raidBody: (title: string) =>
      `Сектор ${title}. Фидер роадмапа сегодня заводит его задачи первыми, а его соты, построенные сегодня, дают двойной мёд.`,
    raidEnds: (h: number, m: number) => `Рейд сменится в полночь UTC, через ${h} ч ${m} мин.`,
    raidNone: 'Рейдить некого: все этапы ниже боссов закрыты.',
    round: (sec: number, left: number) => `Раунд Королевы: каждые ${sec} с, следующий через ${left} с. Полоса света — её раунд, поднимающийся по сотам.`,
    roundNone: 'Раунд Королевы неизвестен: доска не дала пульса.',
    targets: 'Приоритетные цели: самые быстрые свободные соты',
    targetsNone: 'Свободной задачи переноса сейчас нет. Фидер роадмапа заводит следующие каждый час.',
    attack: 'взять',
    fn: 'фн',
    sectors: 'Секторы',
    captured: 'захвачен',
    underAttack: 'под атакой',
    openFront: 'открытый фронт',
    noTasks: 'задач ещё нет',
    locked: 'закрыт',
    inFlight: 'в полёте',
    free: 'свободно',
    unknown: 'неизвестно: GitHub не ответил',
    raidTag: 'рейд',
    bosses: 'Боссы',
    bossHp: 'HP: код, который ещё переписать',
    bossHpUnknown: 'HP: ещё не измерено',
    bossOpens: (pct: number) =>
      `Бой открывается, когда построено ${Math.round(BOSS_OPENS_AT * 100)}% сот ниже (правило этой доски). Сейчас построено: ${pct}%.`,
    bossOpen: 'Бой открыт: половина сот ниже построена.',
    bossWhy: 'Что на самом деле стоит на пути:',
    builders: 'Строители: чьи полосы построили соты .t27',
    buildersBody: 'Из публичного лидерборда Королевы: принятые задачи, чья граница называла файл .t27, и её XP.',
    buildersNone: 'Ни одна полоса ещё не построила соту .t27.',
    buildersDown: 'Лидерборд Королевы не ответил.',
    cells: 'сот',
    unclaimed: 'полосу никто не назвал своей',
    boardDown: 'Доска Королевы не ответила, поэтому кораблей нет: корабль рисуется, только если доска говорит, что пчела работает.',
    githubDown: 'GitHub не ответил на поиск задач, поэтому видны только зерно и контур.',
    loading: 'Читаю соты…',
    ships: 'Корабли над сотами прямо сейчас',
    shipsNone: 'Сейчас ни одна пчела не строит соту переноса.',
    legend: 'Обозначения',
  },
} as const

function stageOf(goals: GameGoal[], repo: string, lang: string): number | null {
  const both = goals.find((g) => g.repos.includes(repo) && g.languages.includes(lang))
  if (both) return both.stage
  const byRepo = goals.find((g) => g.repos.includes(repo))
  return byRepo ? byRepo.stage : null
}

const STATE_ORDER: Record<CellState, number> = {
  seed: 0, built: 1, cracked: 2, review: 3, building: 4, held: 5, target: 6, future: 7,
}

type SearchRow = { number: number; title: string; closed_at?: string | null; pull_request?: unknown }

async function search(q: string): Promise<SearchRow[]> {
  const r = await fetch(
    `https://api.github.com/search/issues?per_page=100&sort=created&order=asc&q=${encodeURIComponent(q)}`,
    { credentials: 'omit' },
  )
  if (!r.ok) throw new Error(String(r.status))
  const j = (await r.json()) as { items?: SearchRow[] }
  return (j.items ?? []).filter((row) => !row.pull_request)
}

const size = (bytes: number) =>
  bytes >= 1e6 ? `${(bytes / 1e6).toFixed(bytes >= 1e7 ? 0 : 1)} MB` : `${Math.max(1, Math.round(bytes / 1e3))} KB`

export default function QueenRoadmapGame({
  lang,
  goals,
  issueRepo,
  goalStates,
  measuredBytes,
}: {
  lang: 'en' | 'ru'
  goals: GameGoal[]
  issueRepo: string
  goalStates: Record<number, 'open' | 'closed'> | null
  /** Bytes of source still to rewrite per stage, from the count; absent or 0 means not measured. */
  measuredBytes: Record<number, number>
}) {
  const c = lang === 'ru' ? COPY.ru : COPY.en
  const [open, setOpen] = useState<SearchRow[] | null>(null)
  const [done, setDone] = useState<SearchRow[] | null>(null)
  const [defects, setDefects] = useState<SearchRow[]>([])
  const [githubDown, setGithubDown] = useState(false)
  const [board, setBoard] = useState<Record<number, string> | null>(null)
  const [pulse, setPulse] = useState<{ lastRoundAt: string | null; roundSeconds: number } | null>(null)
  const [boardDown, setBoardDown] = useState(false)
  const [builders, setBuilders] = useState<Builder[] | null | 'down'>(null)
  const [now, setNow] = useState(() => Date.now())

  useEffect(() => {
    let live = true
    const base = `repo:${issueRepo} is:issue in:title Port`
    Promise.all([search(`${base} is:open`), search(`${base} is:closed reason:completed`)])
      .then(([o, d]) => {
        if (!live) return
        setOpen(o)
        setDone(d)
      })
      .catch(() => live && setGithubDown(true))
    // Defects against built port files. A failure here costs only the cracks,
    // so it is not reported as GitHub being down.
    search(`repo:${issueRepo} is:issue is:open in:title "specs/port"`)
      .then((rows) => live && setDefects(rows))
      .catch(() => {})
    const readBoard = () =>
      fetch(`${QUEEN_API}/queen/public-board`, { credentials: 'omit' })
        .then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
        .then(
          (raw: {
            cards?: Array<{ number?: unknown; column?: unknown }>
            pulse?: { lastRoundAt?: unknown; roundSeconds?: unknown }
          }) => {
            if (!live) return
            const map: Record<number, string> = {}
            for (const card of raw.cards ?? []) {
              if (typeof card.number === 'number' && typeof card.column === 'string') map[card.number] = card.column
            }
            setBoard(map)
            const p = raw.pulse
            setPulse(
              p && typeof p.roundSeconds === 'number'
                ? { lastRoundAt: typeof p.lastRoundAt === 'string' ? p.lastRoundAt : null, roundSeconds: p.roundSeconds }
                : null,
            )
            setBoardDown(false)
          },
        )
        .catch(() => live && setBoardDown(true))
    readBoard()
    fetch(`${QUEEN_API}/queen/public-leaderboard`, { credentials: 'omit' })
      .then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
      .then((raw: { contributors?: Array<Record<string, unknown>> }) => {
        if (!live) return
        const rows = (raw.contributors ?? [])
          .map((row) => ({
            name: typeof row.name === 'string' ? row.name : '',
            claimed: row.claimed === true,
            specs: typeof row.specs === 'number' ? row.specs : 0,
            xp: typeof row.xp === 'number' ? row.xp : 0,
          }))
          .filter((b) => b.specs > 0)
          .sort((a, b) => b.specs - a.specs || b.xp - a.xp)
          .slice(0, 5)
        setBuilders(rows)
      })
      .catch(() => live && setBuilders('down'))
    const boardTimer = window.setInterval(readBoard, 30_000)
    // One tick a second drives the round countdown and the raid clock.
    const clock = window.setInterval(() => setNow(Date.now()), 1_000)
    return () => {
      live = false
      window.clearInterval(boardTimer)
      window.clearInterval(clock)
    }
  }, [issueRepo])

  const cracked = useMemo(() => crackedTargets(defects.map((d) => d.title)), [defects])

  const tasks = useMemo<PortTask[]>(() => {
    const out: PortTask[] = []
    const add = (row: SearchRow, closed: boolean) => {
      const parsed = parsePortTitle(row.title)
      if (!parsed) return
      const column = board?.[row.number]
      const target = targetOf(row.title)
      const state: CellState = closed
        ? target && cracked.has(target)
          ? 'cracked'
          : 'built'
        : column === 'running'
          ? 'building'
          : column === 'review' || column === 'done'
            ? 'review'
            : column === 'blocked'
              ? 'held'
              : 'target'
      out.push({
        number: row.number,
        title: row.title,
        ...parsed,
        stage: stageOf(goals, parsed.repo, parsed.lang),
        state,
        closedAt: row.closed_at ?? null,
      })
    }
    for (const row of done ?? []) add(row, true)
    for (const row of open ?? []) add(row, false)
    // The order the comb is built in: quickest first, then how far along.
    return out.sort((a, b) => a.units - b.units || STATE_ORDER[a.state] - STATE_ORDER[b.state] || a.number - b.number)
  }, [open, done, board, goals, cracked])

  const day = utcDay(now)
  const raid = raidOf(goals, day)
  const raidGoal = goals.find((g) => g.stage === raid) ?? null
  const toMidnight = msToNextDay(now)
  const phase = pulse ? pulsePhase(pulse.lastRoundAt, pulse.roundSeconds, now) : null
  const honey = honeyOf(tasks, raid, day)
  const share = builtShareBelow(tasks)

  const rows = rowsFor(tasks.length + 1)
  const capacity = (rows * (rows + 1)) / 2
  const shown = tasks.slice(0, capacity - 1)

  // Geometry: pointy-top hexes, apex row at the bottom.
  const s = 15
  const w = Math.sqrt(3) * s
  // The frame's sides run at the comb's own slope, 1/sqrt(3) across per unit
  // down, from an apex 2s below the seed: that clears every edge cell by 0.29 s.
  const topY = s * 2.6
  const baseY = topY + (rows - 1) * 1.5 * s + s * 1.3
  const apexY = baseY + 2 * s
  const frameTop = topY - s * 1.4
  const halfTop = (apexY - frameTop) / Math.sqrt(3)
  const width = 2 * halfTop + 8
  const cx = width / 2
  const height = apexY + 6
  const hex = (x: number, y: number, r: number) =>
    Array.from({ length: 6 }, (_, k) => {
      const a = (Math.PI / 180) * (60 * k - 90)
      return `${(x + r * Math.cos(a)).toFixed(1)},${(y + r * Math.sin(a)).toFixed(1)}`
    }).join(' ')
  const framePoints = `${(cx - halfTop).toFixed(1)},${frameTop.toFixed(1)} ${(cx + halfTop).toFixed(1)},${frameTop.toFixed(1)} ${cx.toFixed(1)},${apexY.toFixed(1)}`

  type Placed = { x: number; y: number; row: number; task: PortTask | null; seed: boolean }
  const placed: Placed[] = []
  let k = 0
  for (let r = 0; r < rows; r += 1) {
    for (let i = 0; i <= r; i += 1) {
      const x = cx + (i - r / 2) * w
      const y = baseY - r * 1.5 * s
      if (k === 0) placed.push({ x, y, row: r, task: null, seed: true })
      else placed.push({ x, y, row: r, task: shown[k - 1] ?? null, seed: false })
      k += 1
    }
  }

  const count = (state: CellState) => tasks.filter((t) => t.state === state).length
  const builtCount = count('built') + count('cracked')
  const highest = placed.reduce(
    (m, p) => (p.task && (p.task.state === 'built' || p.task.state === 'cracked') ? Math.max(m, p.row + 1) : m),
    1,
  )
  const building = placed.filter((p) => p.task?.state === 'building')
  // The raid sector's free cells go first: that is what a raid is.
  const targets = tasks
    .filter((t) => t.state === 'target')
    .sort((a, b) => Number(b.stage === raid) - Number(a.stage === raid) || a.units - b.units || a.number - b.number)
    .slice(0, 8)
  const stageTitle = (n: number | null) => goals.find((g) => g.stage === n)?.title[lang] ?? ''
  const colorOfTask = (t: PortTask) => LANG_COLOR[t.lang] ?? '#7a7f86'
  const loading = !githubDown && (open === null || done === null)
  // Counts are shown only once the task search has answered.
  const known = !githubDown && !loading
  const pulseY = phase === null ? null : apexY - phase * (apexY - frameTop)

  const sector = (g: GameGoal) => {
    const mine = tasks.filter((t) => t.stage === g.stage)
    const b = mine.filter((t) => t.state === 'built' || t.state === 'cracked').length
    const f = mine.filter((t) => t.state === 'building' || t.state === 'review').length
    const o = mine.filter((t) => t.state === 'target' || t.state === 'held').length
    const closed = g.issue !== null && goalStates?.[g.issue] === 'closed'
    // Without the task search every count below is unknown, not zero.
    const status = closed
      ? c.captured
      : githubDown && !g.locked
        ? c.unknown
        : g.locked && mine.length === 0
          ? `${c.locked}: ${g.locked[lang]}`
          : f > 0
            ? c.underAttack
            : o > 0
              ? c.openFront
              : c.noTasks
    const tone = closed ? 'cap' : g.locked && mine.length === 0 ? 'lock' : f > 0 ? 'hot' : o > 0 ? 'open' : 'none'
    return { b, f, o, all: mine.length, status, tone }
  }

  const bosses = goals.filter((g) => g.stage >= 8).sort((a, b) => a.stage - b.stage)
  const maxBoss = Math.max(1, ...bosses.map((g) => measuredBytes[g.stage] ?? 0))
  const cellLabel = (t: PortTask) =>
    t.state === 'cracked' ? c.cracked : c[t.state as 'built' | 'review' | 'building' | 'held' | 'target']

  return (
    <section className="rg" aria-label={c.level}>
      <header className="rg-head">
        <span className="rg-level">{c.level}</span>
        <h2>{c.title}</h2>
        <p>{c.lead}</p>
      </header>

      <div className="rg-hud" role="list">
        <div role="listitem"><strong>{known ? builtCount : '—'}</strong><span>{c.hudBuilt}</span></div>
        <div role="listitem" title={c.hudHoneyHint}>
          <strong className="rg-honey-num">{known ? honey : '—'}</strong>
          <span>{c.hudHoney} ⓘ</span>
        </div>
        <div role="listitem"><strong>{known && board ? count('building') : '—'}</strong><span>{c.hudBuilding}</span></div>
        <div role="listitem"><strong>{known ? count('target') : '—'}</strong><span>{c.hudTargets}</span></div>
        <div role="listitem"><strong>{known ? count('cracked') : '—'}</strong><span>{c.hudCracked}</span></div>
        <div role="listitem"><strong>{known ? `${highest} / ${rows}` : '—'}</strong><span>{c.hudRow}</span></div>
      </div>

      <aside className={`rg-raid${raidGoal ? '' : ' is-none'}`}>
        <b>⚔ {c.raid}</b>
        {raidGoal ? (
          <span>
            {c.raidBody(`${raidGoal.stage} · ${raidGoal.title[lang]}`)}{' '}
            {c.raidEnds(Math.floor(toMidnight / 3_600_000), Math.floor((toMidnight % 3_600_000) / 60_000))}
          </span>
        ) : (
          <span>{c.raidNone}</span>
        )}
      </aside>

      <div className="rg-stage">
        <figure className="rg-fig">
          <figcaption className="rg-cap rg-cap-top">▽ {c.summit}</figcaption>
          <svg
            className="rg-comb"
            viewBox={`0 0 ${width.toFixed(0)} ${height.toFixed(0)}`}
            role="img"
            aria-label={`${c.title}: ${builtCount} ${c.hudBuilt}, ${count('building')} ${c.hudBuilding}`}
          >
            <defs>
              <linearGradient id="rg-beam" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0" stopColor={MARK} stopOpacity="0.85" />
                <stop offset="1" stopColor={MARK} stopOpacity="0" />
              </linearGradient>
              <radialGradient id="rg-honey" cx="50%" cy="40%" r="65%">
                <stop offset="0" stopColor="#ffe28a" />
                <stop offset="1" stopColor="#e0a100" />
              </radialGradient>
              <linearGradient id="rg-pulse-fill" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0" stopColor={MARK} stopOpacity="0" />
                <stop offset="0.5" stopColor={MARK} stopOpacity="0.32" />
                <stop offset="1" stopColor={MARK} stopOpacity="0" />
              </linearGradient>
              <clipPath id="rg-frame-clip">
                <polygon points={framePoints} />
              </clipPath>
            </defs>

            {/* The frame of the mark: the triangle every cell sits inside. */}
            <polygon className="rg-frame" points={framePoints} />

            {/* The Queen's round, climbing from the apex; drawn under the cells. */}
            {pulseY !== null && (
              <rect
                className="rg-pulse"
                x={0}
                y={(pulseY - s * 1.2).toFixed(1)}
                width={width.toFixed(0)}
                height={(s * 2.4).toFixed(1)}
                fill="url(#rg-pulse-fill)"
                clipPath="url(#rg-frame-clip)"
              />
            )}

            {placed.map((p, i) => {
              if (p.seed) {
                return (
                  <g key="seed" className="rg-cell rg-seed">
                    <polygon points={hex(p.x, p.y, s - 1)} />
                    <text x={p.x} y={p.y + 3.5} textAnchor="middle">t27c</text>
                    <title>{c.seed}</title>
                  </g>
                )
              }
              if (!p.task) {
                return <polygon key={i} className="rg-cell rg-future" points={hex(p.x, p.y, s - 1.5)} />
              }
              const t = p.task
              const inRaid = raid !== null && t.stage === raid
              return (
                <a
                  key={t.number}
                  href={`https://github.com/${issueRepo}/issues/${t.number}`}
                  target="_blank"
                  rel="noreferrer noopener"
                  className={`rg-cell rg-${t.state}${inRaid ? ' rg-in-raid' : ''}`}
                  style={{ ['--rg-lang' as string]: colorOfTask(t) }}
                >
                  <polygon points={hex(p.x, p.y, s - 1.5)} />
                  {t.state === 'cracked' && (
                    <path
                      className="rg-crack"
                      d={`M${(p.x - s * 0.55).toFixed(1)},${(p.y - s * 0.35).toFixed(1)} l${(s * 0.35).toFixed(1)},${(s * 0.3).toFixed(1)} l${(s * 0.15).toFixed(1)},${(-s * 0.25).toFixed(1)} l${(s * 0.35).toFixed(1)},${(s * 0.55).toFixed(1)} l${(s * 0.25).toFixed(1)},${(-s * 0.2).toFixed(1)}`}
                    />
                  )}
                  {t.state !== 'target' && t.state !== 'held' && t.state !== 'cracked' && (
                    <text x={p.x} y={p.y + 3} textAnchor="middle">{t.units}</text>
                  )}
                  <title>{`#${t.number} · ${t.title}\n${stageTitle(t.stage)}${inRaid ? ` · ${c.raidCell}` : ''}\n${cellLabel(t)}`}</title>
                </a>
              )
            })}

            {/* Ships: one per cell the Queen's board says a bee is building. */}
            {building.map((p, n) => {
              const sx = p.x + (n % 2 === 0 ? -1 : 1) * w * 0.55
              const sy = p.y - s * 2.3
              return (
                <g key={`ship-${p.task!.number}`} className="rg-ship-group" style={{ animationDelay: `${(n % 5) * 0.4}s` }}>
                  <polygon className="rg-beam" points={`${sx - 2},${sy + 6} ${sx + 2},${sy + 6} ${p.x + s * 0.7},${p.y} ${p.x - s * 0.7},${p.y}`} fill="url(#rg-beam)" />
                  <g transform={`translate(${sx.toFixed(1)} ${sy.toFixed(1)}) scale(1.35)`}>
                    <path className="rg-flame" d="M-3,-7 L0,-13 L3,-7 Z" />
                    <path className="rg-ship" d="M0,8 L7,-5 L2,-3 L0,-7 L-2,-3 L-7,-5 Z" />
                    <circle className="rg-cockpit" cx="0" cy="-1" r="1.8" />
                  </g>
                  <title>{`#${p.task!.number} · ${p.task!.title}`}</title>
                </g>
              )
            })}
          </svg>
          <figcaption className="rg-cap rg-cap-bottom">{c.seed} · {c.quick}</figcaption>
          <p className="rg-round">
            {pulse && phase !== null
              ? c.round(pulse.roundSeconds, Math.max(0, Math.round((1 - phase) * pulse.roundSeconds)))
              : boardDown
                ? c.boardDown
                : c.roundNone}
          </p>
        </figure>

        <aside className="rg-side">
          <h3>{c.legend}</h3>
          <ul className="rg-legend">
            <li><i className="rg-k rg-k-built" />{c.built}</li>
            <li><i className="rg-k rg-k-cracked" />{c.cracked}</li>
            <li><i className="rg-k rg-k-review" />{c.review}</li>
            <li><i className="rg-k rg-k-building" />{c.building}</li>
            <li><i className="rg-k rg-k-target" />{c.target}</li>
            <li><i className="rg-k rg-k-raid" />{c.raidCell}</li>
            <li><i className="rg-k rg-k-held" />{c.held}</li>
            <li><i className="rg-k rg-k-future" />{c.future}</li>
          </ul>
          <h3>{c.ships}</h3>
          {boardDown ? (
            <p className="rg-note">{c.boardDown}</p>
          ) : building.length === 0 ? (
            <p className="rg-note">{c.shipsNone}</p>
          ) : (
            <ul className="rg-ships">
              {building.map((p) => (
                <li key={p.task!.number}>
                  <a href={`https://github.com/${issueRepo}/issues/${p.task!.number}`} target="_blank" rel="noreferrer noopener">
                    #{p.task!.number}
                  </a>{' '}
                  {p.task!.path}
                </li>
              ))}
            </ul>
          )}
          <h3>{c.builders}</h3>
          <p className="rg-note">{c.buildersBody}</p>
          {builders === 'down' ? (
            <p className="rg-note">{c.buildersDown}</p>
          ) : builders === null ? (
            <p className="rg-note">{c.loading}</p>
          ) : builders.length === 0 ? (
            <p className="rg-note">{c.buildersNone}</p>
          ) : (
            <ol className="rg-builders">
              {builders.map((b, n) => (
                <li key={`${b.name}-${n}`}>
                  <span className="rg-builder-name">{b.claimed ? b.name : `${b.name} · ${c.unclaimed}`}</span>
                  <span className="rg-builder-cells">{b.specs} {c.cells}</span>
                  <span className="rg-builder-xp">{b.xp} XP</span>
                </li>
              ))}
            </ol>
          )}
          {githubDown && <p className="rg-note">{c.githubDown}</p>}
          {loading && <p className="rg-note">{c.loading}</p>}
        </aside>
      </div>

      <h3 className="rg-h">{c.targets}</h3>
      {targets.length === 0 ? (
        <p className="rg-note">{githubDown ? c.githubDown : loading ? c.loading : c.targetsNone}</p>
      ) : (
        <ol className="rg-targets">
          {targets.map((t, n) => (
            <li key={t.number} className={t.stage === raid ? 'is-raid' : ''}>
              <span className="rg-rank">{n + 1}</span>
              <span className="rg-chip" style={{ ['--rg-lang' as string]: colorOfTask(t) }}>
                {t.stage === raid ? '⚔ ' : ''}{t.stage ? `S${t.stage}` : '·'} · {t.lang || '?'}
              </span>
              <span className="rg-path" title={t.title}>
                {t.repo === issueRepo ? '' : `${t.repo.replace('gHashTag/', '')}:`}
                {t.path}
              </span>
              <span className="rg-units">{t.units} {c.fn}</span>
              <a href={`https://github.com/${issueRepo}/issues/${t.number}`} target="_blank" rel="noreferrer noopener">
                #{t.number} · {c.attack} →
              </a>
            </li>
          ))}
        </ol>
      )}

      <h3 className="rg-h">{c.sectors}</h3>
      <ul className="rg-sectors">
        {goals
          .filter((g) => g.stage < 8)
          .sort((a, b) => a.stage - b.stage)
          .map((g) => {
            const s2 = sector(g)
            return (
              <li key={g.id} className={`rg-sector rg-tone-${s2.tone}${g.stage === raid ? ' is-raid' : ''}`}>
                <span className="rg-sector-num">{g.stage}</span>
                <b>
                  {g.title[lang]}
                  {g.stage === raid && <span className="rg-raid-tag">⚔ {c.raidTag}</span>}
                </b>
                <span className="rg-sector-status">{s2.status}</span>
                {s2.all > 0 && (
                  <span className="rg-sector-count">
                    {s2.b} {c.built} · {s2.f} {c.inFlight} · {s2.o} {c.free}
                  </span>
                )}
              </li>
            )
          })}
      </ul>

      <h3 className="rg-h">{c.bosses}</h3>
      <ul className="rg-bosses">
        {bosses.map((g) => {
          const hp = measuredBytes[g.stage] ?? 0
          const open2 = known && share >= BOSS_OPENS_AT
          return (
            <li key={g.id} className={`rg-boss${open2 ? ' is-open' : ''}`}>
              <div className="rg-boss-head">
                <span className="rg-boss-num">{g.stage}</span>
                <b>{g.title[lang]}</b>
              </div>
              <div className="rg-boss-hp" aria-label={hp > 0 ? `${c.bossHp}: ${size(hp)}` : c.bossHpUnknown}>
                <span>{hp > 0 ? `${c.bossHp}: ${size(hp)}` : c.bossHpUnknown}</span>
                <div className="rg-boss-bar">
                  <div style={{ width: hp > 0 ? `${Math.max(4, (100 * hp) / maxBoss)}%` : '100%' }} className={hp > 0 ? '' : 'is-unknown'} />
                </div>
              </div>
              <p className="rg-note">
                {known ? (open2 ? c.bossOpen : c.bossOpens(Math.round(share * 100))) : c.unknown}
              </p>
              {g.locked && (
                <p className="rg-note">
                  <b>{c.bossWhy}</b> {g.locked[lang]}
                </p>
              )}
            </li>
          )
        })}
      </ul>
    </section>
  )
}
