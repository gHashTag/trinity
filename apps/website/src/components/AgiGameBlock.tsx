import { useEffect, useState } from 'react'
import { useI18n } from '../i18n/context'
import { idleReason, serverOffsetMs } from './queenHud'
import { BOUNDARY_EXAMPLE_ISSUE, QUEEN_API } from '../lib/queenApi'
import './AgiGameBlock.css'

// What the game is for, and the three moves it actually has.
//
// PlayBlock below already says how a developer contributes. This block says
// why a swarm is worth directing at all, and it carries the one move the site
// never named: writing the boundary that lets the Queen dispatch an issue.
// That move was found by reading /queen/status on 2026-09-20 — eight workers
// idle, 799 dispatches all finished, and 553 of 684 candidates refused for
// stating no boundary. The swarm was never asleep; it was starving, and
// nothing on the site told a visitor that they were the ones holding the food.
//
// DATA-HONESTY, the same rule the Queen page keeps: the two figures here are
// fields of /queen/status read through the gated reader in queenHud, never
// computed here and never defaulted. When the server does not answer, or the
// round is stale, or the counts do not reconcile, the figures are dashes and
// the copy says why. A zero would be a claim; a dash is a reading.
const COPY = {
  en: {
    eyebrow: 'AGI GAME',
    title: 'The swarm works. You decide what it works on.',
    lede: 'Under the board is a supervisor that dispatches real agents against real issues, on its own schedule, without being asked. Workers it has. What it runs short of is work it is allowed to take — and that gap is the opening a player fills. It is also why this is a game rather than a demonstration: the move you make changes what a running system does next.',
    liveLabel: 'The supervisor, on its last round',
    refused: 'refused for stating no boundary',
    checked: 'issues the round looked at',
    absent: 'The supervisor did not answer this request, so there is no figure to print. A dash is the reading; a zero would be a claim.',
    stale: 'The last round is older than the schedule allows, and a stale round explains nothing. The figures wait for a fresh one.',
    busy: 'Every worker is busy. This minute the board is not waiting on anyone.',
    moves: [
      {
        n: '01',
        name: 'Play',
        body: 'Take a cell and write the .t27 spec that generates it. The board, the compiler and the review queue are the ones the swarm itself uses — there is no visitor mode, and no separate contribution process to learn.',
        cta: 'The four moves',
        link: '#play',
      },
      {
        n: '02',
        name: 'Direct',
        body: 'The Queen refuses any issue whose body names no boundary — no list of the paths an agent may touch. Writing that boundary is what turns a dead card into work a swarm can take, and the refusal count above is the scoreboard: it falls when yours lands. The move costs no compute at all, which is exactly why it cannot be automated away from you.',
        cta: 'A boundary done right',
        link: BOUNDARY_EXAMPLE_ISSUE,
        external: true,
      },
      {
        n: '03',
        name: 'Earn',
        body: 'An accepted turn is recorded against the name that made it, as a non-transferable integer, and it will stay one. Attach a tradable token to a unit of proof and the cheapest way to make units becomes renting the compute this network exists to replace. So the counters are real and the wallet is not: every one of them is watch-only today, and this page would rather say so than imply otherwise.',
      },
    ],
    whyTitle: 'Why it is built this way, and what the community gets',
    why1: 'One .t27 spec generates the Zig, the Rust, the C and the Verilog. A rule transcribed into four languages is four rules that agree until somebody edits one; generated from a single source it is one rule. That is the whole argument, and it is the reason a core is worth a swarm.',
    why2: 'What AGI names here is narrower than the phrase usually promises, and deliberately checkable. It is not a claim about a mind. It is a working arrangement in which agents, the people who direct them, and the avatars standing in for those people all act on one public board — where every dispatch, refusal, review and rejection is a number anyone can fetch. Intelligence, in this game, is work that passed review, and the corpus is the record of it.',
    board: 'Open the board',
  },
  ru: {
    eyebrow: 'AGI GAME',
    title: 'Рой работает. Чем он займётся — решаете вы.',
    lede: 'Под доской живёт супервизор: он сам, по своему расписанию и без просьб, отправляет настоящих агентов на настоящие задачи. Рабочих ему хватает. Не хватает работы, которую ему разрешено взять, — и этот зазор заполняет игрок. Поэтому это игра, а не демонстрация: ваш ход меняет то, что работающая система сделает дальше.',
    liveLabel: 'Супервизор на последнем круге',
    refused: 'отклонено за то, что не названа граница',
    checked: 'задач круг успел рассмотреть',
    absent: 'Супервизор на этот запрос не ответил, и печатать нечего. Прочерк — это чтение; ноль был бы утверждением.',
    stale: 'Последний круг старше, чем позволяет расписание, а протухший круг ничего не объясняет. Числа ждут свежего.',
    busy: 'Все рабочие заняты. В эту минуту доска никого не ждёт.',
    moves: [
      {
        n: '01',
        name: 'Играй',
        body: 'Возьмите соту и напишите спеку .t27, которая её порождает. Доска, компилятор и очередь ревью — те же самые, которыми пользуется сам рой: режима гостя нет, и отдельного процесса контрибуции учить не нужно.',
        cta: 'Четыре хода',
        link: '#play',
      },
      {
        n: '02',
        name: 'Управляй',
        body: 'Королева отказывает любой задаче, в теле которой не названа граница — список путей, к которым агенту можно прикасаться. Написать эту границу и значит превратить мёртвую карточку в работу, которую рой способен взять; счётчик отказов наверху и есть табло — он падает, когда ваша граница доезжает. Ход не стоит ни секунды вычислений, и именно поэтому его нельзя автоматизировать в обход вас.',
        cta: 'Граница, написанная как надо',
        link: BOUNDARY_EXAMPLE_ISSUE,
        external: true,
      },
      {
        n: '03',
        name: 'Зарабатывай',
        body: 'Принятый ход записывается на имя того, кто его сделал, непередаваемым целым числом — и останется таким. Привяжите к единице доказательства торгуемый токен, и самым дешёвым способом делать единицы станет аренда тех самых вычислений, ради замены которых сеть и существует. Поэтому счётчики настоящие, а кошелька нет: сегодня каждый из них — только для чтения, и страница скорее скажет это прямо, чем намекнёт на обратное.',
      },
    ],
    whyTitle: 'Почему именно так — и что с этого сообществу',
    why1: 'Одна спека .t27 порождает и Zig, и Rust, и C, и Verilog. Правило, переписанное на четыре языка, — это четыре правила, согласные между собой ровно до первой правки одного из них; порождённое из одного источника, оно одно. В этом весь аргумент — и в этом причина тратить на ядро целый рой.',
    why2: 'Слово AGI здесь значит меньше, чем обычно обещает, и нарочно проверяемо. Это не утверждение про разум. Это работающий порядок, в котором агенты, управляющие ими люди и цифровые аватары, стоящие за этими людьми, действуют на одной открытой доске — где каждая отправка, каждый отказ, каждое ревью и каждый возврат есть число, которое может запросить кто угодно. Разум в этой игре — это работа, прошедшая ревью, а корпус — её запись.',
    board: 'Открыть доску',
  },
} as const

/** The two figures, or nulls, and which sentence explains a missing pair. */
type Live =
  | { kind: 'figures'; refused: number; checked: number | null }
  | { kind: 'absent' | 'stale' | 'busy' }

export default function AgiGameBlock() {
  const { lang } = useI18n()
  const t = COPY[lang === 'ru' ? 'ru' : 'en']
  const [live, setLive] = useState<Live>({ kind: 'absent' })

  // One read, not a poll: this is a homepage, and the figure it carries is an
  // argument rather than an instrument. The Queen page is where it moves.
  useEffect(() => {
    let active = true
    const read = async () => {
      try {
        const sentAt = Date.now()
        const response = await fetch(`${QUEEN_API}/queen/status`, {
          headers: { Accept: 'application/json' },
          cache: 'no-store',
        })
        if (!response.ok) throw new Error(`HTTP ${response.status}`)
        // The server's clock rides on the Date header; absent across origins it
        // stays null and the client's clock is used, exactly as the HUD does.
        const offsetMs = serverOffsetMs(response.headers.get('Date'), sentAt, Date.now())
        const status = await response.json()
        if (!active) return
        const reason = idleReason(status, Date.now() + (offsetMs ?? 0))
        if (reason === null) return setLive({ kind: 'busy' })
        if (reason.kind === 'stale') return setLive({ kind: 'stale' })
        const refused = reason.counts?.find((r) => r.key === 'missingBoundary')?.count ?? null
        setLive(refused === null ? { kind: 'absent' } : { kind: 'figures', refused, checked: reason.checked })
      } catch {
        if (active) setLive({ kind: 'absent' })
      }
    }
    void read()
    return () => {
      active = false
    }
  }, [])

  const note = live.kind === 'figures' ? null : t[live.kind]

  return (
    <section className="agi-game" id="agi-game" aria-labelledby="agi-game-title">
      <div className="agi-game-inner">
        <header className="agi-game-head">
          <span className="agi-game-eyebrow">{t.eyebrow}</span>
          <h2 id="agi-game-title">{t.title}</h2>
          <p>{t.lede}</p>
        </header>

        <div className="agi-game-live" data-state={live.kind}>
          <span className="agi-game-live-label">{t.liveLabel}</span>
          <p className="agi-game-figures">
            <strong>{live.kind === 'figures' ? live.refused : '—'}</strong>
            <span>{t.refused}</span>
            <strong>{live.kind === 'figures' && live.checked !== null ? live.checked : '—'}</strong>
            <span>{t.checked}</span>
          </p>
          {note && <p className="agi-game-note">{note}</p>}
        </div>

        <ol className="agi-game-moves">
          {t.moves.map((move) => (
            <li key={move.n}>
              <span className="agi-move-n">{move.n}</span>
              <strong>{move.name}</strong>
              <p>{move.body}</p>
              {'link' in move && move.link ? (
                <a
                  href={move.link}
                  {...('external' in move && move.external
                    ? { target: '_blank', rel: 'noopener noreferrer' }
                    : null)}
                >
                  {move.cta} →
                </a>
              ) : null}
            </li>
          ))}
        </ol>

        <div className="agi-game-why">
          <h3>{t.whyTitle}</h3>
          <p>{t.why1}</p>
          <p>{t.why2}</p>
          <a className="agi-game-board" href="#/queen">
            {t.board} →
          </a>
        </div>
      </div>
    </section>
  )
}
