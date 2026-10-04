#!/usr/bin/env node
// Compile the Queen WARS arena from one .t27 source into its three projections.
// No experiment configuration, result or metric is authored in React or JSON.
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import {
  CYRILLIC,
  SITE,
  checkSchema,
  compilerErrors,
  constsOf,
  loadCompiler,
  sha256,
  verdictOf,
} from './agents-from-specs.mjs'
import { runSpecTests } from './viewport-from-spec.mjs'

const WASM = 'public/t27/t27_compiler.wasm'
export const WARS_SPEC = 'specs/queen/wars.t27'
export const TS_OUT = 'src/lib/queenWars.generated.ts'
export const JSON_OUT = 'public/queen/wars.json'
export const PUBLIC_SPEC_OUT = 'public/queen/wars.t27'
export const EXPECTED_MODULE = 'queen_wars'

const REQUIRED = {
  KIND: 'str', ID: 'str', NAME: 'str', SCHEMA_VERSION: 'u8', GENERATED: 'arr',
  EVIDENCE_LEVELS: 'arr', CONFIG_STATES: 'arr', EXPERIMENT_STATES: 'arr', RUN_STATES: 'arr', VERDICTS: 'arr',
  EMPTY_METRIC_MEANS_UNKNOWN: 'bool', REAL_GITHUB_TASKS_ONLY: 'bool', VARIABLE_FACTOR: 'str', CONTROLLED_FACTORS: 'arr',
  ISOLATION: 'str', ACCEPTANCE_POLICY: 'str', REVIEW_POLICY: 'str', WINNER_POLICY: 'str', COMPARISON_VALIDITY_POLICY: 'str',
  TRI_ROLE: 'str', TRI_ROLE_EVIDENCE: 'str', TRI_ROLE_SOURCE: 'str',
  METRIC_COUNT: 'u8', METRIC_KEYS: 'arr', METRIC_UNITS: 'arr',
  CONFIG_COUNT: 'u8', CONFIG_IDS: 'arr', CONFIG_NAMES: 'arr', CONFIG_KINDS: 'arr', CONFIG_STATES_BY_ID: 'arr',
  CONFIG_EVIDENCE: 'arr', CONFIG_SOURCES: 'arr', CONFIG_NOTES: 'arr', CONFIG_STATE_EVIDENCE: 'arr',
  CONFIG_STATE_SOURCES: 'arr', CONFIG_STATE_NOTES: 'arr',
  EXPERIMENT_COUNT: 'u8', EXPERIMENT_IDS: 'arr', EXPERIMENT_NAMES: 'arr', EXPERIMENT_REPOS: 'arr',
  EXPERIMENT_ISSUE_URLS: 'arr', EXPERIMENT_ISSUE_NUMBERS: 'arr', EXPERIMENT_ISSUE_UPDATED_AT: 'arr',
  EXPERIMENT_BASE_SHAS: 'arr', EXPERIMENT_EXECUTOR_MODELS: 'arr', EXPERIMENT_MODEL_EVIDENCE: 'arr',
  EXPERIMENT_MODEL_SOURCES: 'arr', EXPERIMENT_PROMPTS: 'arr',
  EXPERIMENT_TOOL_POLICIES: 'arr', EXPERIMENT_BUDGETS: 'arr', EXPERIMENT_ACCEPTANCE: 'arr',
  EXPERIMENT_STATES_BY_ID: 'arr', EXPERIMENT_EVIDENCE: 'arr', EXPERIMENT_NOTES: 'arr',
  RUN_COUNT: 'u8', RUN_IDS: 'arr', RUN_EXPERIMENT_IDS: 'arr', RUN_CONFIG_IDS: 'arr', RUN_STARTED_AT: 'arr',
  RUN_FINISHED_AT: 'arr', RUN_STATES_BY_ID: 'arr', RUN_EVIDENCE: 'arr', RUN_VERDICTS: 'arr', RUN_LOG_SHAS: 'arr',
  RUN_PATCH_SHAS: 'arr', RUN_ARTIFACT_URLS: 'arr', RUN_NOTES: 'arr',
  MEASUREMENT_COUNT: 'u8', MEASUREMENT_RUN_IDS: 'arr', MEASUREMENT_KEYS: 'arr', MEASUREMENT_VALUES: 'arr',
  MEASUREMENT_UNITS: 'arr', MEASUREMENT_EVIDENCE: 'arr', MEASUREMENT_SOURCES: 'arr',
}

const EXPECTED = {
  GENERATED: [TS_OUT, JSON_OUT, PUBLIC_SPEC_OUT],
  EVIDENCE_LEVELS: ['OBSERVED', 'SESSION-OBSERVED', 'SOURCE-CLAIM', 'TARGET', 'UNKNOWN'],
  CONFIG_STATES: ['ready', 'credential-blocked', 'checkpoint-unverified', 'pipeline-only'],
  EXPERIMENT_STATES: ['planned', 'running', 'credential-blocked', 'judged', 'complete', 'invalid'],
  RUN_STATES: ['pending', 'running', 'passed', 'failed', 'blocked'],
  VERDICTS: ['accepted', 'rejected', 'inconclusive', 'not-reviewed'],
  CONFIG_IDS: ['bee-baseline', 'bee-tri', 'bee-jev', 'igla-coder', 'igla-race'],
}

const PARALLEL = {
  METRIC_COUNT: ['METRIC_KEYS', 'METRIC_UNITS'],
  CONFIG_COUNT: ['CONFIG_IDS', 'CONFIG_NAMES', 'CONFIG_KINDS', 'CONFIG_STATES_BY_ID', 'CONFIG_EVIDENCE', 'CONFIG_SOURCES', 'CONFIG_NOTES', 'CONFIG_STATE_EVIDENCE', 'CONFIG_STATE_SOURCES', 'CONFIG_STATE_NOTES'],
  EXPERIMENT_COUNT: ['EXPERIMENT_IDS', 'EXPERIMENT_NAMES', 'EXPERIMENT_REPOS', 'EXPERIMENT_ISSUE_URLS', 'EXPERIMENT_ISSUE_NUMBERS', 'EXPERIMENT_ISSUE_UPDATED_AT', 'EXPERIMENT_BASE_SHAS', 'EXPERIMENT_EXECUTOR_MODELS', 'EXPERIMENT_MODEL_EVIDENCE', 'EXPERIMENT_MODEL_SOURCES', 'EXPERIMENT_PROMPTS', 'EXPERIMENT_TOOL_POLICIES', 'EXPERIMENT_BUDGETS', 'EXPERIMENT_ACCEPTANCE', 'EXPERIMENT_STATES_BY_ID', 'EXPERIMENT_EVIDENCE', 'EXPERIMENT_NOTES'],
  RUN_COUNT: ['RUN_IDS', 'RUN_EXPERIMENT_IDS', 'RUN_CONFIG_IDS', 'RUN_STARTED_AT', 'RUN_FINISHED_AT', 'RUN_STATES_BY_ID', 'RUN_EVIDENCE', 'RUN_VERDICTS', 'RUN_LOG_SHAS', 'RUN_PATCH_SHAS', 'RUN_ARTIFACT_URLS', 'RUN_NOTES'],
  MEASUREMENT_COUNT: ['MEASUREMENT_RUN_IDS', 'MEASUREMENT_KEYS', 'MEASUREMENT_VALUES', 'MEASUREMENT_UNITS', 'MEASUREMENT_EVIDENCE', 'MEASUREMENT_SOURCES'],
}

const same = (a, b) => JSON.stringify(a) === JSON.stringify(b)
const uniq = (values) => new Set(values).size === values.length
const oneOf = (value, values) => values.includes(value)
const shortSha = /^[0-9a-f]{40}$/
const fullSha = /^[0-9a-f]{64}$/
const iso = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/
const httpsUrl = /^https:\/\/\S+$/
const ACCEPTANCE_BY_RUN_STATE = new Map([
  ['passed', 'PASSED'],
  ['failed', 'FAILED'],
  ['blocked', 'BLOCKED'],
])
const COMPARABLE_RUN_STATES = new Set(['passed', 'failed'])
// The variable factor is the TRI decision layer, so a judged or complete
// experiment needs a sealed run of both sides of it. JEV is a comparison arm only.
const PAIRED_ARMS = ['bee-baseline', 'bee-tri']
const REVIEWED_VERDICTS = new Set(['accepted', 'rejected'])
const NONNEGATIVE_NUMBER_UNITS = new Set(['ms', 'usd'])
const NONNEGATIVE_INTEGER_UNITS = new Set(['tokens', 'count', 'lines'])

const validMetricValue = (value, unit) => {
  const number = Number(value)
  if (NONNEGATIVE_NUMBER_UNITS.has(unit)) return Number.isFinite(number) && number >= 0
  if (NONNEGATIVE_INTEGER_UNITS.has(unit)) return Number.isInteger(number) && number >= 0
  if (unit === 'probability') return Number.isFinite(number) && number >= 0 && number <= 1
  return true
}

export function semanticProblems(f, file = WARS_SPEC) {
  const p = []
  if (f.KIND !== 'queen-wars') p.push(`${file}: KIND must be "queen-wars"`)
  if (f.ID !== 'queen/wars') p.push(`${file}: ID must be "queen/wars"`)
  if (f.SCHEMA_VERSION !== 2) p.push(`${file}: SCHEMA_VERSION must be 2`)
  for (const [name, expected] of Object.entries(EXPECTED)) {
    if (!same(f[name], expected)) p.push(`${file}: ${name} must be ${JSON.stringify(expected)}`)
  }
  if (f.REAL_GITHUB_TASKS_ONLY !== true) p.push(`${file}: REAL_GITHUB_TASKS_ONLY must be true`)
  if (f.EMPTY_METRIC_MEANS_UNKNOWN !== true) p.push(`${file}: EMPTY_METRIC_MEANS_UNKNOWN must be true`)
  if (f.VARIABLE_FACTOR !== 'tri-decision-layer') p.push(`${file}: VARIABLE_FACTOR must be tri-decision-layer`)
  if (!oneOf(f.TRI_ROLE_EVIDENCE, f.EVIDENCE_LEVELS)) p.push(`${file}: TRI_ROLE_EVIDENCE is unknown`)
  if (!f.TRI_ROLE_SOURCE.trim()) p.push(`${file}: TRI_ROLE_SOURCE is empty`)
  for (const [countName, arrays] of Object.entries(PARALLEL)) {
    for (const name of arrays) if (f[name].length !== f[countName]) p.push(`${file}: ${name}.length ${f[name].length} != ${countName} ${f[countName]}`)
  }
  for (const ids of ['METRIC_KEYS', 'CONFIG_IDS', 'EXPERIMENT_IDS', 'RUN_IDS']) if (!uniq(f[ids])) p.push(`${file}: ${ids} must be unique`)

  for (let i = 0; i < f.CONFIG_COUNT; i++) {
    if (!oneOf(f.CONFIG_STATES_BY_ID[i], f.CONFIG_STATES)) p.push(`${file}: CONFIG_STATES_BY_ID[${i}] is unknown`)
    if (!oneOf(f.CONFIG_EVIDENCE[i], f.EVIDENCE_LEVELS)) p.push(`${file}: CONFIG_EVIDENCE[${i}] is unknown`)
    if (!oneOf(f.CONFIG_STATE_EVIDENCE[i], f.EVIDENCE_LEVELS)) p.push(`${file}: CONFIG_STATE_EVIDENCE[${i}] is unknown`)
    if (!f.CONFIG_SOURCES[i].trim()) p.push(`${file}: CONFIG_SOURCES[${i}] is empty`)
    if (!f.CONFIG_STATE_SOURCES[i].trim()) p.push(`${file}: CONFIG_STATE_SOURCES[${i}] is empty`)
    if (!f.CONFIG_STATE_NOTES[i].trim()) p.push(`${file}: CONFIG_STATE_NOTES[${i}] is empty`)
  }
  for (let i = 0; i < f.EXPERIMENT_COUNT; i++) {
    const issue = /^https:\/\/github\.com\/([^/]+\/[^/]+)\/issues\/(\d+)$/.exec(f.EXPERIMENT_ISSUE_URLS[i])
    if (!issue) p.push(`${file}: EXPERIMENT_ISSUE_URLS[${i}] is not a canonical GitHub issue URL`)
    else {
      if (issue[1] !== f.EXPERIMENT_REPOS[i]) p.push(`${file}: experiment ${f.EXPERIMENT_IDS[i]} URL repo differs from EXPERIMENT_REPOS`)
      if (issue[2] !== f.EXPERIMENT_ISSUE_NUMBERS[i]) p.push(`${file}: experiment ${f.EXPERIMENT_IDS[i]} URL number differs from EXPERIMENT_ISSUE_NUMBERS`)
    }
    if (!shortSha.test(f.EXPERIMENT_BASE_SHAS[i])) p.push(`${file}: EXPERIMENT_BASE_SHAS[${i}] must be a 40-character git SHA`)
    if (!iso.test(f.EXPERIMENT_ISSUE_UPDATED_AT[i])) p.push(`${file}: EXPERIMENT_ISSUE_UPDATED_AT[${i}] must be UTC ISO-8601 seconds`)
    if (!oneOf(f.EXPERIMENT_STATES_BY_ID[i], f.EXPERIMENT_STATES)) p.push(`${file}: EXPERIMENT_STATES_BY_ID[${i}] is unknown`)
    if (!oneOf(f.EXPERIMENT_EVIDENCE[i], f.EVIDENCE_LEVELS)) p.push(`${file}: EXPERIMENT_EVIDENCE[${i}] is unknown`)
    if (!oneOf(f.EXPERIMENT_MODEL_EVIDENCE[i], f.EVIDENCE_LEVELS)) p.push(`${file}: EXPERIMENT_MODEL_EVIDENCE[${i}] is unknown`)
    if (!f.EXPERIMENT_MODEL_SOURCES[i].trim()) p.push(`${file}: EXPERIMENT_MODEL_SOURCES[${i}] is empty`)
    for (const field of ['EXPERIMENT_PROMPTS', 'EXPERIMENT_TOOL_POLICIES', 'EXPERIMENT_BUDGETS', 'EXPERIMENT_ACCEPTANCE']) {
      if (!f[field][i].trim()) p.push(`${file}: ${field}[${i}] is empty`)
    }
  }

  for (let i = 0; i < f.RUN_COUNT; i++) {
    if (!f.EXPERIMENT_IDS.includes(f.RUN_EXPERIMENT_IDS[i])) p.push(`${file}: run ${f.RUN_IDS[i]} names unknown experiment ${f.RUN_EXPERIMENT_IDS[i]}`)
    if (!f.CONFIG_IDS.includes(f.RUN_CONFIG_IDS[i])) p.push(`${file}: run ${f.RUN_IDS[i]} names unknown config ${f.RUN_CONFIG_IDS[i]}`)
    if (!oneOf(f.RUN_STATES_BY_ID[i], f.RUN_STATES)) p.push(`${file}: run ${f.RUN_IDS[i]} has unknown state ${f.RUN_STATES_BY_ID[i]}`)
    if (!oneOf(f.RUN_EVIDENCE[i], f.EVIDENCE_LEVELS)) p.push(`${file}: run ${f.RUN_IDS[i]} has unknown evidence ${f.RUN_EVIDENCE[i]}`)
    if (!oneOf(f.RUN_VERDICTS[i], f.VERDICTS)) p.push(`${file}: run ${f.RUN_IDS[i]} has unknown verdict ${f.RUN_VERDICTS[i]}`)
    if (f.RUN_VERDICTS[i] === 'accepted' && f.RUN_STATES_BY_ID[i] !== 'passed') {
      p.push(`${file}: run ${f.RUN_IDS[i]} accepted verdict requires run state passed, is ${f.RUN_STATES_BY_ID[i]}`)
    }
    if (f.RUN_STARTED_AT[i] && !iso.test(f.RUN_STARTED_AT[i])) p.push(`${file}: run ${f.RUN_IDS[i]} start is not UTC ISO-8601 seconds`)
    if (f.RUN_FINISHED_AT[i] && !iso.test(f.RUN_FINISHED_AT[i])) p.push(`${file}: run ${f.RUN_IDS[i]} finish is not UTC ISO-8601 seconds`)
    if (iso.test(f.RUN_STARTED_AT[i]) && iso.test(f.RUN_FINISHED_AT[i]) && f.RUN_FINISHED_AT[i] < f.RUN_STARTED_AT[i]) {
      p.push(`${file}: run ${f.RUN_IDS[i]} finish ${f.RUN_FINISHED_AT[i]} is before start ${f.RUN_STARTED_AT[i]}`)
    }
    if (f.RUN_LOG_SHAS[i] && !fullSha.test(f.RUN_LOG_SHAS[i])) p.push(`${file}: run ${f.RUN_IDS[i]} log SHA is not sha256`)
    if (f.RUN_PATCH_SHAS[i] && !fullSha.test(f.RUN_PATCH_SHAS[i])) p.push(`${file}: run ${f.RUN_IDS[i]} patch SHA is not sha256`)
    if (f.RUN_ARTIFACT_URLS[i] && !httpsUrl.test(f.RUN_ARTIFACT_URLS[i])) p.push(`${file}: run ${f.RUN_IDS[i]} artifact URL must use https`)
  }

  const unitByMetric = new Map(f.METRIC_KEYS.map((key, i) => [key, f.METRIC_UNITS[i]]))
  const runIndexById = new Map(f.RUN_IDS.map((id, i) => [id, i]))
  const measurementPairs = new Set()
  const measurementIndexByPair = new Map()
  for (let i = 0; i < f.MEASUREMENT_COUNT; i++) {
    const run = f.MEASUREMENT_RUN_IDS[i]
    const key = f.MEASUREMENT_KEYS[i]
    const pair = `${run}\u0000${key}`
    if (measurementPairs.has(pair)) p.push(`${file}: duplicate measurement ${key} for run ${run}`)
    measurementPairs.add(pair)
    measurementIndexByPair.set(pair, i)
    if (!f.RUN_IDS.includes(run)) p.push(`${file}: measurement ${i} names unknown run ${run}`)
    if (!unitByMetric.has(key)) p.push(`${file}: measurement ${i} names unknown metric ${key}`)
    else if (unitByMetric.get(key) !== f.MEASUREMENT_UNITS[i]) p.push(`${file}: measurement ${i} unit ${f.MEASUREMENT_UNITS[i]} != ${unitByMetric.get(key)} for ${key}`)
    if (!oneOf(f.MEASUREMENT_EVIDENCE[i], f.EVIDENCE_LEVELS)) p.push(`${file}: measurement ${i} has unknown evidence ${f.MEASUREMENT_EVIDENCE[i]}`)
    if (!f.MEASUREMENT_VALUES[i].trim()) p.push(`${file}: measurement ${i} has an empty value; omit unknown metrics`)
    if (!f.MEASUREMENT_SOURCES[i].trim()) p.push(`${file}: measurement ${i} has no source; omit unsupported metrics`)
    const catalogUnit = unitByMetric.get(key)
    if (catalogUnit && !validMetricValue(f.MEASUREMENT_VALUES[i], catalogUnit)) {
      p.push(`${file}: measurement ${i} ${key} value ${f.MEASUREMENT_VALUES[i]} is invalid for unit ${catalogUnit}`)
    }

    const runIndex = runIndexById.get(run)
    if (runIndex === undefined) continue
    if (key === 'acceptance') {
      const state = f.RUN_STATES_BY_ID[runIndex]
      const expected = ACCEPTANCE_BY_RUN_STATE.get(state)
      if (!expected) p.push(`${file}: measurement ${i} acceptance is not allowed while run ${run} state is ${state}`)
      else if (f.MEASUREMENT_VALUES[i] !== expected) {
        p.push(`${file}: measurement ${i} acceptance ${f.MEASUREMENT_VALUES[i]} disagrees with run ${run} state ${state}; expected ${expected}`)
      }
    }
    if (key === 'queen-verdict') {
      const verdict = f.RUN_VERDICTS[runIndex]
      if (f.MEASUREMENT_VALUES[i] !== verdict) {
        p.push(`${file}: measurement ${i} queen-verdict ${f.MEASUREMENT_VALUES[i]} disagrees with run ${run} verdict ${verdict}`)
      }
    }
  }

  for (let i = 0; i < f.EXPERIMENT_COUNT; i++) {
    const experimentState = f.EXPERIMENT_STATES_BY_ID[i]
    if (experimentState !== 'complete' && experimentState !== 'judged') continue
    const experimentId = f.EXPERIMENT_IDS[i]
    if (experimentState === 'complete' && (f.EXPERIMENT_MODEL_EVIDENCE[i] !== 'OBSERVED' || /\bUNKNOWN\b/i.test(f.EXPERIMENT_EXECUTOR_MODELS[i]))) {
      p.push(`${file}: complete experiment ${experimentId} requires an explicit observed executor model and reasoning configuration`)
    }
    for (const required of PAIRED_ARMS) {
      const sealedRun = f.RUN_EXPERIMENT_IDS.some((id, at) => {
        if (id !== experimentId || f.RUN_CONFIG_IDS[at] !== required) return false
        const runId = f.RUN_IDS[at]
        const acceptanceAt = measurementIndexByPair.get(`${runId}\u0000acceptance`)
        const verdictAt = measurementIndexByPair.get(`${runId}\u0000queen-verdict`)
        return COMPARABLE_RUN_STATES.has(f.RUN_STATES_BY_ID[at])
          && REVIEWED_VERDICTS.has(f.RUN_VERDICTS[at])
          && f.RUN_EVIDENCE[at] === 'OBSERVED'
          && iso.test(f.RUN_STARTED_AT[at])
          && iso.test(f.RUN_FINISHED_AT[at])
          && fullSha.test(f.RUN_LOG_SHAS[at])
          && fullSha.test(f.RUN_PATCH_SHAS[at])
          && httpsUrl.test(f.RUN_ARTIFACT_URLS[at])
          && acceptanceAt !== undefined
          && verdictAt !== undefined
          && f.MEASUREMENT_EVIDENCE[acceptanceAt] === 'OBSERVED'
          && f.MEASUREMENT_EVIDENCE[verdictAt] === 'OBSERVED'
      })
      if (!sealedRun) {
        p.push(`${file}: ${experimentState} experiment ${experimentId} has no sealed ${required} run (passed or failed state, accepted or rejected Queen verdict, observed evidence, timestamps, log SHA, patch SHA, https artifact, acceptance and queen-verdict measurements required)`)
      }
    }
  }
  return p
}

const rows = (count, make) => Array.from({ length: count }, (_, i) => make(i))

export function arenaOf(f, specSha) {
  const experiments = rows(f.EXPERIMENT_COUNT, (i) => ({
    id: f.EXPERIMENT_IDS[i],
    name: f.EXPERIMENT_NAMES[i],
    issue: { repo: f.EXPERIMENT_REPOS[i], number: Number(f.EXPERIMENT_ISSUE_NUMBERS[i]), url: f.EXPERIMENT_ISSUE_URLS[i], updatedAt: f.EXPERIMENT_ISSUE_UPDATED_AT[i] },
    baseSha: f.EXPERIMENT_BASE_SHAS[i],
    executorModel: f.EXPERIMENT_EXECUTOR_MODELS[i],
    prompt: f.EXPERIMENT_PROMPTS[i],
    promptSha256: sha256(Buffer.from(f.EXPERIMENT_PROMPTS[i], 'utf8')),
    toolPolicy: f.EXPERIMENT_TOOL_POLICIES[i],
    toolPolicySha256: sha256(Buffer.from(f.EXPERIMENT_TOOL_POLICIES[i], 'utf8')),
    budget: f.EXPERIMENT_BUDGETS[i],
    acceptance: f.EXPERIMENT_ACCEPTANCE[i],
    acceptanceSha256: sha256(Buffer.from(f.EXPERIMENT_ACCEPTANCE[i], 'utf8')),
    modelEvidence: f.EXPERIMENT_MODEL_EVIDENCE[i], modelSource: f.EXPERIMENT_MODEL_SOURCES[i],
    state: f.EXPERIMENT_STATES_BY_ID[i], evidence: f.EXPERIMENT_EVIDENCE[i], note: f.EXPERIMENT_NOTES[i],
  }))
  return {
    source: { spec: WARS_SPEC, publicSpec: PUBLIC_SPEC_OUT, sha256: specSha, schemaVersion: f.SCHEMA_VERSION },
    name: f.NAME,
    vocabularies: { evidence: f.EVIDENCE_LEVELS, configStates: f.CONFIG_STATES, experimentStates: f.EXPERIMENT_STATES, runStates: f.RUN_STATES, verdicts: f.VERDICTS },
    protocol: {
      realGitHubTasksOnly: f.REAL_GITHUB_TASKS_ONLY, variableFactor: f.VARIABLE_FACTOR, controlledFactors: f.CONTROLLED_FACTORS,
      isolation: f.ISOLATION, acceptancePolicy: f.ACCEPTANCE_POLICY, reviewPolicy: f.REVIEW_POLICY, winnerPolicy: f.WINNER_POLICY,
      comparisonValidityPolicy: f.COMPARISON_VALIDITY_POLICY,
      triRole: f.TRI_ROLE, triRoleEvidence: f.TRI_ROLE_EVIDENCE, triRoleSource: f.TRI_ROLE_SOURCE,
      emptyMetricMeansUnknown: f.EMPTY_METRIC_MEANS_UNKNOWN,
    },
    metricCatalog: rows(f.METRIC_COUNT, (i) => ({ key: f.METRIC_KEYS[i], unit: f.METRIC_UNITS[i] })),
    configurations: rows(f.CONFIG_COUNT, (i) => ({
      id: f.CONFIG_IDS[i], name: f.CONFIG_NAMES[i], kind: f.CONFIG_KINDS[i], state: f.CONFIG_STATES_BY_ID[i],
      evidence: f.CONFIG_EVIDENCE[i], source: f.CONFIG_SOURCES[i], note: f.CONFIG_NOTES[i],
      stateEvidence: f.CONFIG_STATE_EVIDENCE[i], stateSource: f.CONFIG_STATE_SOURCES[i], stateNote: f.CONFIG_STATE_NOTES[i],
    })),
    experiments,
    runs: rows(f.RUN_COUNT, (i) => ({
      id: f.RUN_IDS[i], experimentId: f.RUN_EXPERIMENT_IDS[i], configId: f.RUN_CONFIG_IDS[i], startedAt: f.RUN_STARTED_AT[i] || null,
      finishedAt: f.RUN_FINISHED_AT[i] || null, state: f.RUN_STATES_BY_ID[i], evidence: f.RUN_EVIDENCE[i], verdict: f.RUN_VERDICTS[i],
      logSha256: f.RUN_LOG_SHAS[i] || null, patchSha256: f.RUN_PATCH_SHAS[i] || null,
      artifactUrl: f.RUN_ARTIFACT_URLS[i] || null, note: f.RUN_NOTES[i],
    })),
    measurements: rows(f.MEASUREMENT_COUNT, (i) => ({
      runId: f.MEASUREMENT_RUN_IDS[i], key: f.MEASUREMENT_KEYS[i], value: f.MEASUREMENT_VALUES[i], unit: f.MEASUREMENT_UNITS[i],
      evidence: f.MEASUREMENT_EVIDENCE[i], source: f.MEASUREMENT_SOURCES[i],
    })),
  }
}

export const renderJson = (arena) => JSON.stringify(arena, null, 2) + '\n'
export const renderTs = (arena) => `// GENERATED by scripts/queen-wars-from-spec.mjs from ${WARS_SPEC}\n// spec sha256 ${arena.source.sha256}\n// Do not edit: change the .t27 source and regenerate.\n\nexport const QUEEN_WARS = ${JSON.stringify(arena, null, 2)} as const\n\nexport type QueenWarsArena = typeof QUEEN_WARS\n`

export async function buildWars({ specText, analyze }) {
  const problems = []
  const analysis = analyze(specText)
  const verdict = verdictOf(analysis)
  if (!verdict.typecheckOk || verdict.discarded > 0 || !verdict.hirOk) problems.push(`${WARS_SPEC}: compiler verdict not clean (${JSON.stringify(verdict)})`)
  problems.push(...compilerErrors(analysis).map((message) => `${WARS_SPEC}: ${message}`))
  if (/[^\x00-\x7f]/.test(specText)) problems.push(`${WARS_SPEC}: non-ASCII byte in the spec (L3)`)
  if (CYRILLIC.test(specText)) problems.push(`${WARS_SPEC}: Cyrillic in the spec (LANG-EN)`)
  if (analysis.ast?.name !== EXPECTED_MODULE) problems.push(`${WARS_SPEC}: module must be ${EXPECTED_MODULE}, is ${analysis.ast?.name ?? 'missing'}`)

  let consts = {}
  try { consts = constsOf(analysis) } catch (error) { problems.push(`${WARS_SPEC}: ${error.message}`) }
  problems.push(...checkSchema(consts, REQUIRED, {}, WARS_SPEC))
  const fields = Object.fromEntries(Object.entries(consts).map(([name, decl]) => [name, decl.value]))
  let tests = { tests: 0, asserts: 0, failures: [] }
  if (problems.length === 0) {
    problems.push(...semanticProblems(fields))
    tests = runSpecTests(analysis, fields)
    if (tests.tests === 0) problems.push(`${WARS_SPEC}: no test block; the arena must test its own invariants`)
    problems.push(...tests.failures.map((message) => `${WARS_SPEC}: test ${message}`))
  }
  const specSha = sha256(Buffer.from(specText, 'utf8'))
  const arena = problems.length ? null : arenaOf(fields, specSha)
  return {
    problems, verdict, fields, specSha, tests, arena,
    json: arena ? renderJson(arena) : null,
    ts: arena ? renderTs(arena) : null,
    publicSpec: arena ? specText : null,
  }
}

async function main() {
  const check = process.argv.includes('--check')
  const jsonOnly = process.argv.includes('--json')
  const specPath = join(SITE, WARS_SPEC)
  if (!existsSync(specPath)) { console.error(`queen-wars-from-spec: ${WARS_SPEC} is missing`); process.exit(1) }
  const specText = readFileSync(specPath, 'utf8')
  const analyze = await loadCompiler(readFileSync(join(SITE, WASM)))
  const out = await buildWars({ specText, analyze })
  if (out.problems.length) {
    console.error(`queen-wars-from-spec: ${out.problems.length} problem(s)`)
    for (const problem of out.problems) console.error(`  ${problem}`)
    process.exit(1)
  }
  if (jsonOnly) { process.stdout.write(out.json); return }
  const targets = [[TS_OUT, out.ts], [JSON_OUT, out.json], [PUBLIC_SPEC_OUT, out.publicSpec]]
  if (check) {
    const stale = targets.filter(([rel, value]) => !existsSync(join(SITE, rel)) || readFileSync(join(SITE, rel), 'utf8') !== value)
    if (stale.length) {
      console.error(`queen-wars-from-spec --check: stale ${stale.map(([rel]) => rel).join(', ')}; run node scripts/queen-wars-from-spec.mjs`)
      process.exit(1)
    }
  } else {
    for (const [rel, value] of targets) {
      mkdirSync(dirname(join(SITE, rel)), { recursive: true })
      writeFileSync(join(SITE, rel), value)
    }
  }
  console.log(`queen-wars-from-spec: ${check ? 'up to date' : 'wrote'} ${targets.map(([rel]) => rel).join(', ')}; spec ${out.specSha.slice(0, 16)}; ${out.fields.CONFIG_COUNT} configurations, ${out.fields.EXPERIMENT_COUNT} experiment(s), ${out.fields.RUN_COUNT} run(s); spec tests ${out.tests.tests}, asserts ${out.tests.asserts}, all hold`)
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  main().catch((error) => { console.error(error); process.exit(1) })
}
