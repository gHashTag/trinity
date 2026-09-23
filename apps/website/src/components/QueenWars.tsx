import { useState } from 'react'
import { QUEEN_WARS } from '../lib/queenWars.generated'
import './QueenWars.css'

type WarsRun = {
  id: string
  experimentId: string
  configId: string
  startedAt: string | null
  finishedAt: string | null
  state: string
  evidence: string
  verdict: string
  logSha256: string | null
  patchSha256: string | null
  artifactUrl: string | null
  note: string
}

type WarsMeasurement = {
  runId: string
  key: string
  value: string
  unit: string
  evidence: string
  source: string
}

const COPY = {
  en: {
    kicker: 'REAL-TASK AGENT ARENA',
    title: 'WARS',
    lead: 'One issue. One pinned commit. The same Bee, tools and acceptance gates. Only the decision layer may change.',
    source: 'SOURCE .T27',
    protocol: 'CONTROLLED PROTOCOL',
    factor: 'variable',
    fixed: 'held constant',
    comparisonRule: 'comparison validity',
    jevRole: 'JEV role',
    task: 'REAL TASK',
    experimentPicker: 'EXPERIMENT',
    base: 'base',
    model: 'executor model',
    modelSource: 'MODEL EVIDENCE',
    issueUpdated: 'issue snapshot',
    state: 'experiment',
    configurations: 'COMBATANTS',
    evidence: 'evidence',
    evidenceSource: 'CAPABILITY SOURCE',
    stateEvidence: 'state evidence',
    stateSource: 'STATE SOURCE',
    run: 'run',
    noRun: 'NO WITNESSED RUN',
    metrics: 'SCOREBOARD',
    metric: 'metric',
    metricSource: 'MEASUREMENT SOURCE',
    unknown: 'not measured',
    ledger: 'RUN LEDGER',
    noLedger: 'No completed arm has been sealed into the .t27 ledger yet.',
    pipeline: 'TRAINING PIPELINE',
    pipelineCopy: 'IGLA enters this arena only after an executable checkpoint exists. Until then its pipeline is visible, but it has no benchmark score.',
    control: 'CONTROL',
    decision: 'DECISION LAYER',
    ownModel: 'OWN MODEL TARGET',
    training: 'TRAINING RACE',
    specHash: 'spec sha256',
  },
  ru: {
    kicker: 'АРЕНА АГЕНТОВ НА РЕАЛЬНЫХ ЗАДАЧАХ',
    title: 'ВОЙНЫ',
    lead: 'Одна issue. Один закреплённый commit. Та же Bee, инструменты и ворота приёмки. Меняться может только слой решений.',
    source: 'ИСТОЧНИК .T27',
    protocol: 'КОНТРОЛИРУЕМЫЙ ПРОТОКОЛ',
    factor: 'переменная',
    fixed: 'зафиксировано',
    comparisonRule: 'валидность сравнения',
    jevRole: 'роль JEV',
    task: 'РЕАЛЬНАЯ ЗАДАЧА',
    experimentPicker: 'ЭКСПЕРИМЕНТ',
    base: 'база',
    model: 'модель исполнителя',
    modelSource: 'СВИДЕТЕЛЬСТВО МОДЕЛИ',
    issueUpdated: 'снимок issue',
    state: 'эксперимент',
    configurations: 'УЧАСТНИКИ',
    evidence: 'свидетельство',
    evidenceSource: 'ИСТОЧНИК ВОЗМОЖНОСТИ',
    stateEvidence: 'свидетельство состояния',
    stateSource: 'ИСТОЧНИК СОСТОЯНИЯ',
    run: 'запуск',
    noRun: 'НЕТ ПОДТВЕРЖДЁННОГО ЗАПУСКА',
    metrics: 'ТАБЛИЦА РЕЗУЛЬТАТОВ',
    metric: 'метрика',
    metricSource: 'ИСТОЧНИК ИЗМЕРЕНИЯ',
    unknown: 'не измерено',
    ledger: 'ЖУРНАЛ ЗАПУСКОВ',
    noLedger: 'Ни одна завершённая рука ещё не запечатана в журнале .t27.',
    pipeline: 'КОНВЕЙЕР ОБУЧЕНИЯ',
    pipelineCopy: 'IGLA входит на эту арену только после появления исполняемого checkpoint. До этого конвейер виден, но benchmark-оценки у него нет.',
    control: 'КОНТРОЛЬ',
    decision: 'СЛОЙ РЕШЕНИЙ',
    ownModel: 'ЦЕЛЬ: СВОЯ МОДЕЛЬ',
    training: 'ГОНКА ОБУЧЕНИЯ',
    specHash: 'sha256 спеки',
  },
} as const

const STATE_RU: Record<string, string> = {
  ready: 'готово',
  'credential-blocked': 'ключ недоступен',
  'checkpoint-unverified': 'checkpoint не подтверждён',
  'pipeline-only': 'только конвейер',
  planned: 'запланирован',
  running: 'выполняется',
  complete: 'завершён',
  invalid: 'недействителен',
  passed: 'пройден',
  failed: 'провален',
  blocked: 'заблокирован',
}

const kindLabel = (id: string, c: typeof COPY.en | typeof COPY.ru) => {
  if (id === 'bee-baseline') return c.control
  if (id === 'bee-jev') return c.decision
  if (id === 'igla-coder') return c.ownModel
  return c.training
}

const short = (value: string, n = 12) => value.length > n ? `${value.slice(0, n)}…` : value

const outcome = (value: string | null | undefined) => {
  const normalized = value?.toLowerCase()
  if (['blocked', 'credential-blocked', 'failed', 'rejected', 'invalid'].includes(normalized ?? '')) return 'blocked'
  if (['passed', 'accepted', 'complete', 'ready'].includes(normalized ?? '')) return 'positive'
  if (normalized === 'running') return 'running'
  return 'neutral'
}

function Evidence({ value }: { value: string }) {
  return <span className="queen-wars-evidence" data-evidence={value}>{value}</span>
}

export function QueenWars({ lang }: { lang: 'en' | 'ru' }) {
  const c = COPY[lang]
  const [selectedExperimentId, setSelectedExperimentId] = useState<string>(QUEEN_WARS.experiments[0].id)
  const experiment = QUEEN_WARS.experiments.find((item) => item.id === selectedExperimentId) ?? QUEEN_WARS.experiments[0]
  const runs = QUEEN_WARS.runs as readonly unknown[] as readonly WarsRun[]
  const experimentRuns = runs.filter((run) => run.experimentId === experiment.id)
  const measurements = QUEEN_WARS.measurements as readonly unknown[] as readonly WarsMeasurement[]
  const state = (value: string) => lang === 'ru' ? (STATE_RU[value] ?? value) : value
  const runFor = (configId: string) => [...experimentRuns].reverse().find((run) => run.configId === configId)
  const measureFor = (configId: string, key: string) => {
    const run = runFor(configId)
    return run ? measurements.find((item) => item.runId === run.id && item.key === key) : undefined
  }

  return (
    <section className="queen-wars" aria-labelledby="queen-wars-title">
      <header className="queen-wars-head">
        <div>
          <p className="queen-wars-kicker">{c.kicker}</p>
          <h2 id="queen-wars-title"><span aria-hidden="true">⚔</span> {c.title}</h2>
          <p>{c.lead}</p>
        </div>
        <a className="queen-wars-source" href="queen/wars.t27">
          <span>{c.source}</span>
          <code>{short(QUEEN_WARS.source.sha256, 16)}</code>
        </a>
      </header>

      <section className="queen-wars-protocol" aria-labelledby="queen-wars-protocol-title">
        <header>
          <span>01</span>
          <h3 id="queen-wars-protocol-title">{c.protocol}</h3>
          <Evidence value="TARGET" />
        </header>
        <dl>
          <div>
            <dt>{c.factor}</dt>
            <dd>{QUEEN_WARS.protocol.variableFactor}</dd>
          </div>
          <div>
            <dt>{c.fixed}</dt>
            <dd>{QUEEN_WARS.protocol.controlledFactors.join(' · ')}</dd>
          </div>
          <div>
            <dt>{c.comparisonRule}</dt>
            <dd>{QUEEN_WARS.protocol.comparisonValidityPolicy}</dd>
          </div>
          <div>
            <dt>{c.jevRole}</dt>
            <dd className="queen-wars-claim">
              <span>{QUEEN_WARS.protocol.jevRole}</span>
              <Evidence value={QUEEN_WARS.protocol.jevRoleEvidence} />
              <a href={QUEEN_WARS.protocol.jevRoleSource}>{c.evidenceSource}</a>
            </dd>
          </div>
        </dl>
      </section>

      <section className="queen-wars-mission" aria-labelledby="queen-wars-task-title">
        <header>
          <span>02</span>
          <h3 id="queen-wars-task-title">{c.task}</h3>
          <Evidence value={experiment.evidence} />
        </header>
        <div className="queen-wars-experiment-picker">
          <label htmlFor="queen-wars-experiment">{c.experimentPicker}</label>
          <select
            id="queen-wars-experiment"
            value={selectedExperimentId}
            onChange={(event) => setSelectedExperimentId(event.currentTarget.value)}
          >
            {QUEEN_WARS.experiments.map((item) => (
              <option key={item.id} value={item.id}>#{item.issue.number} · {item.name}</option>
            ))}
          </select>
        </div>
        <div className="queen-wars-mission-main">
          <a href={experiment.issue.url}>#{experiment.issue.number} · {experiment.name}</a>
          <p>{experiment.issue.repo}</p>
        </div>
        <dl>
          <div><dt>{c.base}</dt><dd><code>{short(experiment.baseSha, 16)}</code></dd></div>
          <div>
            <dt>{c.model}</dt>
            <dd className="queen-wars-model-evidence">
              <span>{experiment.executorModel}</span>
              <Evidence value={experiment.modelEvidence} />
              <details className="queen-wars-inline-source">
                <summary>{c.modelSource}</summary>
                <p>{experiment.modelSource}</p>
              </details>
            </dd>
          </div>
          <div><dt>{c.issueUpdated}</dt><dd><time dateTime={experiment.issue.updatedAt}>{experiment.issue.updatedAt}</time></dd></div>
          <div><dt>{c.state}</dt><dd>{state(experiment.state)}</dd></div>
        </dl>
      </section>

      <section className="queen-wars-arena" aria-labelledby="queen-wars-config-title">
        <header className="queen-wars-section-title">
          <span>03</span>
          <h3 id="queen-wars-config-title">{c.configurations}</h3>
        </header>
        <div className="queen-wars-lanes">
          {QUEEN_WARS.configurations.map((config, index) => {
            const run = runFor(config.id)
            return (
              <article className={`queen-wars-lane is-${config.id}`} data-evidence={config.evidence} key={config.id}>
                <header>
                  <small>{String(index + 1).padStart(2, '0')} · {kindLabel(config.id, c)}</small>
                  <h4>{config.name}</h4>
                </header>
                <div className={`queen-wars-state is-${run?.state ?? config.state}`} data-outcome={outcome(run?.state ?? config.state)}>
                  <i aria-hidden="true" />
                  <span>{state(run?.state ?? config.state)}</span>
                  <Evidence value={config.stateEvidence} />
                </div>
                <p className="queen-wars-capability-note">{config.note}</p>
                <p className="queen-wars-state-note">{config.stateNote}</p>
                <dl>
                  <div><dt>{c.evidence}</dt><dd><Evidence value={config.evidence} /></dd></div>
                  <div><dt>{c.stateEvidence}</dt><dd><Evidence value={config.stateEvidence} /></dd></div>
                  <div><dt>{c.run}</dt><dd>{run ? run.id : '—'}</dd></div>
                </dl>
                <footer>
                  <div className="queen-wars-run-result" data-outcome={outcome(run?.verdict)}>
                    <span>{run ? run.verdict : c.noRun}</span>
              <Evidence value={run?.evidence ?? config.stateEvidence} />
                  </div>
                  <details className="queen-wars-config-source" open>
                    <summary>{c.evidenceSource}</summary>
                    <p>{config.source}</p>
                  </details>
                  <details className="queen-wars-config-source">
                    <summary>{c.stateSource}</summary>
                    <p>{config.stateSource}</p>
                  </details>
                </footer>
              </article>
            )
          })}
        </div>
      </section>

      <section className="queen-wars-score" aria-labelledby="queen-wars-score-title">
        <header className="queen-wars-section-title">
          <span>04</span>
          <h3 id="queen-wars-score-title">{c.metrics}</h3>
        </header>
        <div className="queen-wars-table-scroll" tabIndex={0} role="region" aria-label={c.metrics}>
          <table>
            <thead>
              <tr>
                <th scope="col">{c.metric}</th>
                {QUEEN_WARS.configurations.map((config) => <th scope="col" key={config.id}>{config.name}</th>)}
              </tr>
            </thead>
            <tbody>
              {QUEEN_WARS.metricCatalog.map((metric) => (
                <tr key={metric.key}>
                  <th scope="row"><span>{metric.key}</span><small>{metric.unit}</small></th>
                  {QUEEN_WARS.configurations.map((config) => {
                    const value = measureFor(config.id, metric.key)
                    return (
                      <td
                        key={config.id}
                        data-evidence={value?.evidence ?? 'UNKNOWN'}
                        data-outcome={outcome(value?.value)}
                      >
                        {value ? <>
                          <strong>{value.value}</strong>
                          <small>{value.unit}</small>
                          <Evidence value={value.evidence} />
                          <details className="queen-wars-measurement-source">
                            <summary>{c.metricSource}</summary>
                            <p>{value.source}</p>
                          </details>
                        </> : <><span aria-label={c.unknown}>—</span><Evidence value="UNKNOWN" /></>}
                      </td>
                    )
                  })}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="queen-wars-ledger" aria-labelledby="queen-wars-ledger-title">
        <header className="queen-wars-section-title">
          <span>05</span>
          <h3 id="queen-wars-ledger-title">{c.ledger}</h3>
        </header>
        {experimentRuns.length === 0 ? <p className="queen-wars-empty">{c.noLedger}</p> : (
          <ol>
            {experimentRuns.map((run) => (
              <li key={run.id} data-evidence={run.evidence} data-outcome={outcome(run.state)}>
                <b>{run.configId}</b>
                <span className="queen-wars-ledger-state">{state(run.state)} · {run.verdict}</span>
                <code>{run.patchSha256 ? short(run.patchSha256, 16) : 'patch —'}</code>
                <Evidence value={run.evidence} />
                <p>{run.note}</p>
              </li>
            ))}
          </ol>
        )}
      </section>

      <section className="queen-wars-training" aria-labelledby="queen-wars-training-title">
        <header className="queen-wars-section-title">
          <span>06</span>
          <h3 id="queen-wars-training-title">{c.pipeline}</h3>
        </header>
        <p>{c.pipelineCopy}</p>
        <div className="queen-wars-flow" aria-label={c.pipeline}>
          <span>IGLA .t27 CORPUS</span><i aria-hidden="true">→</i><span>TRAIN</span><i aria-hidden="true">→</i><span>CHECKPOINT + SHA</span><i aria-hidden="true">→</i><span>WARS</span><i aria-hidden="true">→</i><span>QUEEN VERDICT</span>
        </div>
      </section>

      <footer className="queen-wars-foot">
        <span>{c.specHash}</span>
        <code>{QUEEN_WARS.source.sha256}</code>
      </footer>
    </section>
  )
}
