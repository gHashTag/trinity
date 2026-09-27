import { useState, type CSSProperties } from 'react'
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
    triRole: 'TRI role (the judge)',
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
    pipelineCopy: 'IGLA enters this arena when one of its checkpoints runs an arena issue under the same gates. The pilot reports trained checkpoints; none has run an arena issue yet, so IGLA has no arena score.',
    control: 'CONTROL',
    triLayer: 'TRI DECISION LAYER',
    decision: 'COMPARISON ARM',
    ownModel: 'OWN MODEL TARGET',
    training: 'TRAINING RACE',
    specHash: 'spec sha256',
    glance: 'CAMPAIGN AT A GLANCE',
    statIssues: 'real issues',
    statRuns: 'sealed runs',
    statAccepted: 'accepted by the gates',
    statMeasured: 'measurements',
    statNoWinner: 'No winner is declared: the executor model id is not recorded in the ledger.',
    matrix: 'HEAD TO HEAD',
    matrixHint: 'One cell is one arm on one real issue. Choose a row to open it below.',
    open: 'open',
    noArmRun: 'no run',
    notMeasured: 'not measured in this experiment',
    mutantsKilled: 'mutants killed',
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
    triRole: 'Роль TRI (судья)',
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
    pipelineCopy: 'IGLA входит на эту арену, когда один из её checkpoint решает issue арены под теми же воротами. Пилот сообщает об обученных checkpoint, но ни один ещё не решал issue арены, поэтому оценки на арене у IGLA нет.',
    control: 'КОНТРОЛЬ',
    triLayer: 'СЛОЙ РЕШЕНИЙ TRI',
    decision: 'СРАВНИТЕЛЬНОЕ ПЛЕЧО',
    ownModel: 'ЦЕЛЬ: СВОЯ МОДЕЛЬ',
    training: 'ГОНКА ОБУЧЕНИЯ',
    specHash: 'sha256 спеки',
    glance: 'КАМПАНИЯ ОДНИМ ВЗГЛЯДОМ',
    statIssues: 'реальных issue',
    statRuns: 'запечатанных запусков',
    statAccepted: 'приняты воротами',
    statMeasured: 'измерений',
    statNoWinner: 'Победитель не объявлен: в журнале не записан id модели исполнителя.',
    matrix: 'ЛИЦОМ К ЛИЦУ',
    matrixHint: 'Одна клетка — одна рука на одной реальной issue. Выберите строку, чтобы открыть её ниже.',
    open: 'открыть',
    noArmRun: 'нет запуска',
    notMeasured: 'не измерено в этом эксперименте',
    mutantsKilled: 'поймано мутантов',
  },
} as const

const STATE_RU: Record<string, string> = {
  ready: 'готово',
  'credential-blocked': 'ключ недоступен',
  'checkpoint-unverified': 'checkpoint не подтверждён',
  'pipeline-only': 'только конвейер',
  planned: 'запланирован',
  running: 'выполняется',
  judged: 'оценён, без победителя',
  complete: 'завершён',
  invalid: 'недействителен',
  passed: 'пройден',
  failed: 'провален',
  blocked: 'заблокирован',
}

const kindLabel = (id: string, c: typeof COPY.en | typeof COPY.ru) => {
  if (id === 'bee-baseline') return c.control
  if (id === 'bee-tri') return c.triLayer
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

// Units whose values compare on one axis within a row; a bar shows each arm's
// value relative to the largest in that row. Verdicts and probabilities do not.
const BAR_UNITS = new Set(['ms', 'tokens', 'count', 'lines', 'usd'])
// The arms a head-to-head row shows: the paired arms, then the comparison arm.
const MATRIX_ARMS = ['bee-baseline', 'bee-tri', 'bee-jev'] as const

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
  const latestRun = (experimentId: string, configId: string) =>
    [...runs].reverse().find((run) => run.experimentId === experimentId && run.configId === configId)

  // Scoreboard: only the arms that ran this experiment, and only the metrics
  // at least one of them measured. The rest are listed, never shown as zero.
  const armsWithRuns = QUEEN_WARS.configurations.filter((config) => runFor(config.id))
  const scoreArms = armsWithRuns.length ? armsWithRuns : QUEEN_WARS.configurations
  const measuredMetrics = QUEEN_WARS.metricCatalog.filter((metric) => scoreArms.some((config) => measureFor(config.id, metric.key)))
  const unmeasuredMetrics = QUEEN_WARS.metricCatalog.filter((metric) => !measuredMetrics.includes(metric))
  const rowMax = (key: string) => Math.max(0, ...scoreArms.map((config) => Number(measureFor(config.id, key)?.value)).filter(Number.isFinite))

  const sealedRuns = runs.filter((run) => run.evidence === 'OBSERVED' && run.artifactUrl && run.logSha256 && run.patchSha256)
  const glance = [
    { value: QUEEN_WARS.experiments.length, label: c.statIssues },
    { value: sealedRuns.length, label: c.statRuns },
    { value: `${runs.filter((run) => run.verdict === 'accepted').length}/${runs.length}`, label: c.statAccepted },
    { value: measurements.length, label: c.statMeasured },
  ]
  const unranked = QUEEN_WARS.experiments.some((item) => item.state === 'judged')
  // A column no experiment has a run for would be a column of "no run".
  const matrixArms = MATRIX_ARMS.filter((id) => runs.some((run) => run.configId === id))

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

      <section className="queen-wars-glance" aria-label={c.glance}>
        <dl>
          {glance.map((item) => (
            <div key={item.label}>
              <dd>{item.value}</dd>
              <dt>{item.label}</dt>
            </div>
          ))}
        </dl>
        {unranked && <p>{c.statNoWinner}</p>}
      </section>

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
            <dt>{c.triRole}</dt>
            <dd className="queen-wars-claim">
              <span>{QUEEN_WARS.protocol.triRole}</span>
              <Evidence value={QUEEN_WARS.protocol.triRoleEvidence} />
              <a href={QUEEN_WARS.protocol.triRoleSource}>{c.evidenceSource}</a>
            </dd>
          </div>
        </dl>
      </section>

      <section className="queen-wars-matrix" aria-labelledby="queen-wars-matrix-title">
        <header className="queen-wars-section-title">
          <span>02</span>
          <h3 id="queen-wars-matrix-title">{c.matrix}</h3>
        </header>
        <p className="queen-wars-matrix-hint">{c.matrixHint}</p>
        <div className="queen-wars-table-scroll" tabIndex={0} role="region" aria-label={c.matrix}>
          <table>
            <thead>
              <tr>
                <th scope="col">{c.task}</th>
                {matrixArms.map((id) => (
                  <th scope="col" key={id}>{QUEEN_WARS.configurations.find((config) => config.id === id)?.name ?? id}</th>
                ))}
                <th scope="col">{c.state}</th>
              </tr>
            </thead>
            <tbody>
              {QUEEN_WARS.experiments.map((item) => (
                <tr key={item.id} aria-current={item.id === experiment.id ? 'true' : undefined}>
                  <th scope="row">
                    <button type="button" onClick={() => setSelectedExperimentId(item.id)}>
                      <span>#{item.issue.number}</span>
                      <small>{item.name}</small>
                    </button>
                  </th>
                  {matrixArms.map((id) => {
                    const run = latestRun(item.id, id)
                    const killed = run ? measurements.find((m) => m.runId === run.id && m.key === 'mutants-killed') : undefined
                    return (
                      <td key={id} data-outcome={outcome(run?.verdict)} data-evidence={run?.evidence ?? 'UNKNOWN'}>
                        {run ? <>
                          <strong>{run.verdict}</strong>
                          <small>{state(run.state)}{killed ? ` · ${c.mutantsKilled}: ${killed.value}` : ''}</small>
                        </> : <span className="queen-wars-matrix-empty">{c.noArmRun}</span>}
                      </td>
                    )
                  })}
                  <td data-outcome={outcome(item.state)}><small>{state(item.state)}</small></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="queen-wars-mission" aria-labelledby="queen-wars-task-title">
        <header>
          <span>03</span>
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
          <span>04</span>
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
          <span>05</span>
          <h3 id="queen-wars-score-title">{c.metrics}</h3>
        </header>
        <div className="queen-wars-table-scroll" tabIndex={0} role="region" aria-label={c.metrics}>
          <table>
            <thead>
              <tr>
                <th scope="col">{c.metric}</th>
                {scoreArms.map((config) => <th scope="col" key={config.id}>{config.name}</th>)}
              </tr>
            </thead>
            <tbody>
              {measuredMetrics.map((metric) => (
                <tr key={metric.key}>
                  <th scope="row"><span>{metric.key}</span><small>{metric.unit}</small></th>
                  {scoreArms.map((config) => {
                    const value = measureFor(config.id, metric.key)
                    const max = rowMax(metric.key)
                    const bar = value && BAR_UNITS.has(value.unit) && max > 0 ? Number(value.value) / max : null
                    return (
                      <td
                        key={config.id}
                        data-evidence={value?.evidence ?? 'UNKNOWN'}
                        data-outcome={outcome(value?.value)}
                      >
                        {value ? <>
                          <strong>{value.value}</strong>
                          <small>{value.unit}</small>
                          {bar !== null && <span className="queen-wars-bar" style={{ '--bar': bar.toFixed(3) } as CSSProperties} aria-hidden="true" />}
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
        {unmeasuredMetrics.length > 0 && (
          <p className="queen-wars-unmeasured">
            <Evidence value="UNKNOWN" />
            <span>{c.notMeasured}:</span> {unmeasuredMetrics.map((metric) => metric.key).join(' · ')}
          </p>
        )}
      </section>

      <section className="queen-wars-ledger" aria-labelledby="queen-wars-ledger-title">
        <header className="queen-wars-section-title">
          <span>06</span>
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
          <span>07</span>
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
