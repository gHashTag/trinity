// The Queen's LANES view: how many bees can work at once, why that number is
// what it is, and how a player raises it.
//
// The view exists because on 2026-09-17 the swarm reached 100% utilisation for
// the first time and produced nothing at all. Ten lanes were busy; every turn
// ended `refused` in zero seconds, because all five provider keys answered
// HTTP 429 (z.ai code 1302, "Rate limit reached"). A lane occupied by a refusal
// looks exactly like a lane doing work, so the headline number lied.
//
// Hence the shape of this panel: utilisation is shown, and immediately beside it
// the evidence for whether it is *work*. The two are never printed as one.
//
// Following the contract in queenHud.ts: every number here is a field the public
// /queen/status endpoint already sends. The ones the swarm knows but does not
// publish — how many keys are live, who contributed them, what each has spent —
// are named as missing, with the endpoint that would carry them. A panel that
// invents them would be the same lie in a different font.

import { useI18n } from '../i18n/context'
import './QueenLanes.css'

export interface LanesWorkers {
  capacity: number
  active: number
  idle: number
  utilization: number
}

export interface LanesDispatch {
  issue: number
  dispatchedAt: string
  finishedAt: string | null
  outcome: string | null
}

export interface LanesStatus {
  workers?: LanesWorkers | null
  dispatches?: {
    total: number
    finished: number
    running: number
    unreviewed?: number
    latest?: LanesDispatch | null
  } | null
}

export interface LanesCopy {
  directive: string
  directiveBody: string
}

const COPY = {
  en: {
    capacity: 'LANES',
    capacityHint: 'bees that can work at once',
    active: 'BUSY',
    idle: 'FREE',
    util: 'UTILISATION',
    lawTitle: 'THE LANE LAW',
    law: 'A lane is not a setting. Capacity is the number of provider keys that answer, times the lanes each key is allowed to open. The worker ceiling is only a ceiling: it cannot conjure a lane a key does not pay for.',
    lawFormula: 'capacity = live keys × lanes per key',
    lawUnknown: 'How many keys are live is not on the public endpoint. This panel will not guess it.',
    workTitle: 'IS IT WORK?',
    workLead: 'Utilisation counts occupied lanes. A refused turn occupies one exactly like a working turn, so the two must be read together, never as one number.',
    lastDispatch: 'last dispatch',
    instantRefusal: 'Zero-second refusal — the lane was occupied and nothing was attempted. This is what a spent quota looks like from outside.',
    refusalHint: 'Refusals are cheap and fast, so a starved swarm reports its best utilisation ever.',
    healthy: 'The last dispatch ran for a measurable time. That is necessary for real work, and not sufficient: only a branch proves it.',
    pending: 'The last dispatch is still running.',
    noDispatch: 'No dispatch recorded yet.',
    unreviewed: 'finished, awaiting review',
    donateTitle: 'DONATE A LANE',
    donateLead: 'The currency is quota, not lanes. A key that answers adds both; a lane without quota multiplies zero. This is the one contribution that raises the ceiling for everybody at once.',
    xpTitle: 'HOW XP IS EARNED',
    xpRule: 'XP accrues to the owner of the key a turn ran on — but only for a turn that reached a branch. Never per dispatch: a refused turn occupies a lane exactly like a working one, and paying for it would pay best when the swarm is most broken.',
    neverTitle: 'THIS PAGE NEVER TAKES A KEY',
    never: 'No field here accepts a provider key, and none ever will. This is a public static page; a secret typed into it is a secret published. Keys are handed over out of band and held by the server alone.',
    missingTitle: 'NOT WIRED YET',
    missing: 'The contributor board, the per-key health and the XP ledger need an endpoint that does not exist yet:',
    missingEndpoint: 'GET /queen/public-lanes → { keys: [{ owner, state: "live" | "cooldown" | "spent", lanes, turnsToBranch }] }',
    missingWhy: 'Until it answers, this view shows the swarm-wide numbers above and says nothing about who paid for them.',
    branchTitle: 'WHERE THE WORK GOES',
    branchLead: 'A finished turn writes a branch inside the container, which deliberately holds no push credential — so nothing reaches GitHub until something outside pushes it. That publishing step is where a day of bee work can sit unseen.',
    branchGit: 'GitButler is the intended safe path for it: virtual branches let the queue be published and reviewed in slices instead of as one irreversible flood.',
  },
  ru: {
    capacity: 'ПОЛОСЫ',
    capacityHint: 'пчёл могут работать одновременно',
    active: 'ЗАНЯТО',
    idle: 'СВОБОДНО',
    util: 'ЗАГРУЗКА',
    lawTitle: 'ЗАКОН ПОЛОСЫ',
    law: 'Полоса — не настройка. Ёмкость это число отвечающих ключей провайдера, умноженное на число полос, разрешённых одному ключу. Потолок воркеров — только потолок: он не создаст полосу, за которую не платит ключ.',
    lawFormula: 'ёмкость = живые ключи × полос на ключ',
    lawUnknown: 'Сколько ключей живо — публичный эндпоинт не сообщает. Эта панель не станет угадывать.',
    workTitle: 'А ЭТО РАБОТА?',
    workLead: 'Загрузка считает занятые полосы. Отказной ход занимает полосу ровно так же, как рабочий, поэтому два числа читаются вместе и никогда не сливаются в одно.',
    lastDispatch: 'последняя выдача',
    instantRefusal: 'Отказ за ноль секунд — полоса была занята, а попытки не было. Так снаружи выглядит исчерпанная квота.',
    refusalHint: 'Отказы дёшевы и мгновенны, поэтому голодающий рой показывает лучшую загрузку в своей истории.',
    healthy: 'Последняя выдача длилась измеримое время. Это необходимо для настоящей работы и недостаточно: доказывает её только ветка.',
    pending: 'Последняя выдача ещё выполняется.',
    noDispatch: 'Выдач пока не записано.',
    unreviewed: 'завершено, ждёт ревью',
    donateTitle: 'ОТДАТЬ ПОЛОСУ',
    donateLead: 'Валюта — квота, а не полосы. Отвечающий ключ добавляет и то и другое; полоса без квоты умножает ноль. Это единственный вклад, который поднимает потолок сразу для всех.',
    xpTitle: 'КАК НАЧИСЛЯЕТСЯ XP',
    xpRule: 'XP идёт владельцу ключа, на котором прошёл ход, — но только за ход, дошедший до ветки. Никогда за диспатч: отказной ход занимает полосу так же, как рабочий, и плата за него платила бы лучше всего тогда, когда рой сломан сильнее всего.',
    neverTitle: 'ЭТА СТРАНИЦА НИКОГДА НЕ ПРИНИМАЕТ КЛЮЧ',
    never: 'Здесь нет поля для ключа провайдера и не будет. Это публичная статическая страница; секрет, введённый в неё, — секрет опубликованный. Ключи передаются вне игры и хранятся только на сервере.',
    missingTitle: 'ЕЩЁ НЕ ПОДКЛЮЧЕНО',
    missing: 'Доска вкладчиков, здоровье по каждому ключу и журнал XP требуют эндпоинта, которого пока нет:',
    missingEndpoint: 'GET /queen/public-lanes → { keys: [{ owner, state: "live" | "cooldown" | "spent", lanes, turnsToBranch }] }',
    missingWhy: 'Пока он не отвечает, вкладка показывает общие числа роя выше и молчит о том, кто за них заплатил.',
    branchTitle: 'КУДА УХОДИТ РАБОТА',
    branchLead: 'Завершённый ход пишет ветку внутри контейнера, который намеренно не держит push-креденшел, — поэтому до GitHub ничего не доходит, пока её не выложит что-то снаружи. Именно на этом шаге день работы пчёл может простоять невидимым.',
    branchGit: 'GitButler — предполагаемый безопасный путь для этого: виртуальные ветки позволяют публиковать и ревьюить очередь порциями, а не одним необратимым потоком.',
  },
} as const

/** Milliseconds a dispatch lasted, or null when it has not finished. */
const durationMs = (d: LanesDispatch): number | null => {
  if (!d.finishedAt) return null
  const ms = Date.parse(d.finishedAt) - Date.parse(d.dispatchedAt)
  return Number.isFinite(ms) ? ms : null
}

export function QueenLanes({
  status,
  error,
  c,
}: {
  status: LanesStatus | null
  error: string | null
  c: LanesCopy
}) {
  const { lang } = useI18n()
  const t = lang === 'ru' ? COPY.ru : COPY.en

  const workers = status?.workers ?? null
  const dispatches = status?.dispatches ?? null
  const latest = dispatches?.latest ?? null
  const ran = latest ? durationMs(latest) : null
  // A refusal that took no measurable time never reached the provider. That is
  // the signature of a spent quota, and the only way to tell it apart from a
  // busy swarm without reading the container's own logs.
  const instant = latest?.outcome === 'refused' && ran !== null && ran < 1000

  return (
    <section className="queen27-lanes" aria-label={c.directive}>
      <header className="queen27-lanes-head">
        <h2>{c.directive}</h2>
        <p>{c.directiveBody}</p>
      </header>

      <div className="queen27-lanes-body">
        <div className="queen27-lanes-figures">
          <figure className="queen27-lanes-figure queen27-lanes-figure-wide">
            <figcaption>{t.capacity}</figcaption>
            <b>{workers ? workers.capacity : '—'}</b>
            <small>{t.capacityHint}</small>
          </figure>
          <figure className="queen27-lanes-figure">
            <figcaption>{t.active}</figcaption>
            <b>{workers ? workers.active : '—'}</b>
          </figure>
          <figure className="queen27-lanes-figure">
            <figcaption>{t.idle}</figcaption>
            <b>{workers ? workers.idle : '—'}</b>
          </figure>
          <figure className="queen27-lanes-figure">
            <figcaption>{t.util}</figcaption>
            <b>{workers ? `${workers.utilization}%` : '—'}</b>
          </figure>
        </div>

        {error ? <p className="queen27-lanes-error">{error}</p> : null}

        <article className={`queen27-lanes-card${instant ? ' queen27-lanes-card-alarm' : ''}`}>
          <h3>{t.workTitle}</h3>
          <p>{t.workLead}</p>
          {latest ? (
            <>
              <p className="queen27-lanes-meta">
                {t.lastDispatch}: #{latest.issue}
                {latest.outcome ? ` · ${latest.outcome}` : ''}
                {ran !== null ? ` · ${(ran / 1000).toFixed(1)}s` : ''}
              </p>
              {instant ? (
                <>
                  <p className="queen27-lanes-alarm">{t.instantRefusal}</p>
                  <p className="queen27-lanes-note">{t.refusalHint}</p>
                </>
              ) : ran === null ? (
                <p className="queen27-lanes-note">{t.pending}</p>
              ) : (
                <p className="queen27-lanes-note">{t.healthy}</p>
              )}
            </>
          ) : (
            <p className="queen27-lanes-note">{t.noDispatch}</p>
          )}
          {dispatches?.unreviewed ? (
            <p className="queen27-lanes-meta">
              {dispatches.unreviewed} {t.unreviewed}
            </p>
          ) : null}
        </article>

        <article className="queen27-lanes-card">
          <h3>{t.lawTitle}</h3>
          <p>{t.law}</p>
          <code className="queen27-lanes-formula">{t.lawFormula}</code>
          <p className="queen27-lanes-note">{t.lawUnknown}</p>
        </article>

        <article className="queen27-lanes-card">
          <h3>{t.donateTitle}</h3>
          <p>{t.donateLead}</p>
          <h4>{t.xpTitle}</h4>
          <p>{t.xpRule}</p>
          <h4>{t.neverTitle}</h4>
          <p className="queen27-lanes-warn">{t.never}</p>
        </article>

        <article className="queen27-lanes-card">
          <h3>{t.missingTitle}</h3>
          <p>{t.missing}</p>
          <code className="queen27-lanes-formula">{t.missingEndpoint}</code>
          <p className="queen27-lanes-note">{t.missingWhy}</p>
        </article>

        <article className="queen27-lanes-card">
          <h3>{t.branchTitle}</h3>
          <p>{t.branchLead}</p>
          <p className="queen27-lanes-note">{t.branchGit}</p>
        </article>
      </div>
    </section>
  )
}

export default QueenLanes
