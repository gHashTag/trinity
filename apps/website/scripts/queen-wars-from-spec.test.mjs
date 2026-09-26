import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { SITE, loadCompiler, sha256 } from './agents-from-specs.mjs'
import { JSON_OUT, PUBLIC_SPEC_OUT, TS_OUT, WARS_SPEC, buildWars, semanticProblems } from './queen-wars-from-spec.mjs'

const analyze = await loadCompiler(readFileSync(join(SITE, 'public/t27/t27_compiler.wasm')))
const source = readFileSync(join(SITE, WARS_SPEC), 'utf8')
const replaceConst = (text, name, value) => {
  const pattern = new RegExp(`^(pub const ${name} : [a-z0-9\\[\\]-]+ = )[^;]+;`, 'm')
  assert.match(text, pattern, `${name} exists in the spec`)
  return text.replace(pattern, `$1${value};`)
}

const parsedFields = async () => {
  const out = await buildWars({ specText: source, analyze })
  assert.deepEqual(out.problems, [])
  return structuredClone(out.fields)
}

const appendRun = (fields, run) => {
  fields.RUN_COUNT += 1
  fields.RUN_IDS.push(run.id)
  fields.RUN_EXPERIMENT_IDS.push(run.experimentId)
  fields.RUN_CONFIG_IDS.push(run.configId)
  fields.RUN_STARTED_AT.push(run.startedAt)
  fields.RUN_FINISHED_AT.push(run.finishedAt)
  fields.RUN_STATES_BY_ID.push(run.state)
  fields.RUN_EVIDENCE.push(run.evidence)
  fields.RUN_VERDICTS.push(run.verdict)
  fields.RUN_LOG_SHAS.push(run.logSha)
  fields.RUN_PATCH_SHAS.push(run.patchSha)
  fields.RUN_ARTIFACT_URLS.push(run.artifactUrl)
  fields.RUN_NOTES.push(run.note)
}

const appendMeasurement = (fields, measurement) => {
  fields.MEASUREMENT_COUNT += 1
  fields.MEASUREMENT_RUN_IDS.push(measurement.runId)
  fields.MEASUREMENT_KEYS.push(measurement.key)
  fields.MEASUREMENT_VALUES.push(measurement.value)
  fields.MEASUREMENT_UNITS.push(measurement.unit)
  fields.MEASUREMENT_EVIDENCE.push(measurement.evidence)
  fields.MEASUREMENT_SOURCES.push(measurement.source)
}

test('the WARS source compiles, evaluates its tests and renders all projections', async () => {
  const out = await buildWars({ specText: source, analyze })
  assert.deepEqual(out.problems, [])
  assert.equal(out.verdict.typecheckOk, true)
  assert.equal(out.verdict.discarded, 0)
  assert.ok(out.tests.tests >= 4)
  assert.ok(out.tests.asserts >= 15)
  assert.equal(out.specSha, sha256(Buffer.from(source, 'utf8')))
  assert.equal(out.arena.source.sha256, out.specSha)
  assert.equal(out.arena.configurations.length, 4)
  assert.equal(out.arena.configurations[1].evidence, 'SOURCE-CLAIM')
  assert.equal(out.arena.configurations[1].stateEvidence, 'OBSERVED')
  assert.match(out.arena.configurations[1].source, /^https:\/\/docs\.typesafe\.ai\//)
  assert.equal(out.arena.experiments[0].issue.number, 4328)
  assert.equal(out.arena.experiments[0].modelEvidence, 'UNKNOWN')
  assert.equal(out.arena.protocol.triRoleEvidence, 'OBSERVED')
  assert.equal(out.arena.runs.length, 1)
  assert.equal(out.arena.measurements.length, 5)
})

test('committed projections are deterministic and current', async () => {
  const first = await buildWars({ specText: source, analyze })
  const second = await buildWars({ specText: source, analyze })
  assert.equal(first.ts, second.ts)
  assert.equal(first.json, second.json)
  assert.equal(readFileSync(join(SITE, TS_OUT), 'utf8'), first.ts)
  assert.equal(readFileSync(join(SITE, JSON_OUT), 'utf8'), first.json)
  assert.equal(readFileSync(join(SITE, PUBLIC_SPEC_OUT), 'utf8'), source)
})

test('a false in-spec assert blocks emission despite a clean typecheck', async () => {
  const changed = replaceConst(source, 'REAL_GITHUB_TASKS_ONLY', 'false')
  const out = await buildWars({ specText: changed, analyze })
  assert.equal(out.verdict.typecheckOk, true)
  assert.equal(out.ts, null)
  assert.ok(out.problems.some((problem) => /REAL_GITHUB_TASKS_ONLY|assert .* false/.test(problem)), out.problems.join('\n'))
})

test('parallel-array drift is refused', async () => {
  const changed = replaceConst(source, 'CONFIG_NAMES', '["Bee baseline"]')
  const out = await buildWars({ specText: changed, analyze })
  assert.equal(out.ts, null)
  assert.ok(out.problems.some((problem) => /CONFIG_NAMES/.test(problem)), out.problems.join('\n'))
})

test('metric catalog keys are unique', async () => {
  const fields = await parsedFields()
  fields.METRIC_KEYS[10] = fields.METRIC_KEYS[9]
  fields.METRIC_UNITS[10] = fields.METRIC_UNITS[9]

  const problems = semanticProblems(fields, 'metric-catalog.t27')
  assert.ok(problems.some((problem) => /METRIC_KEYS must be unique/.test(problem)), problems.join('\n'))
})

test('a fabricated measurement without a source is refused', async () => {
  const changed = source.replace(
    '"session-observed agent UTC timestamps 2026-09-23T04:10:25Z through 2026-09-23T04:32:27Z"',
    '""',
  )
  assert.notEqual(changed, source)
  const out = await buildWars({ specText: changed, analyze })
  assert.equal(out.ts, null)
  assert.ok(out.problems.some((problem) => /unknown run|no source/.test(problem)), out.problems.join('\n'))
})

test('duplicate measurements for the same run and metric are refused', async () => {
  const fields = await parsedFields()
  appendMeasurement(fields, {
    runId: fields.MEASUREMENT_RUN_IDS[0],
    key: fields.MEASUREMENT_KEYS[0],
    value: fields.MEASUREMENT_VALUES[0],
    unit: fields.MEASUREMENT_UNITS[0],
    evidence: fields.MEASUREMENT_EVIDENCE[0],
    source: 'duplicate test evidence',
  })

  const problems = semanticProblems(fields, 'duplicate.t27')
  assert.ok(problems.some((problem) => /duplicate measurement .*acceptance/.test(problem)), problems.join('\n'))
})

test('a run finish before its start is refused', async () => {
  const fields = await parsedFields()
  fields.RUN_FINISHED_AT[0] = '2026-09-23T04:00:00Z'

  const problems = semanticProblems(fields, 'time-order.t27')
  assert.ok(problems.some((problem) => /finish .* before start/.test(problem)), problems.join('\n'))
})

test('acceptance measurements must use the controlled value for the run state', async () => {
  const fields = await parsedFields()
  fields.MEASUREMENT_VALUES[0] = 'PASSED'

  const problems = semanticProblems(fields, 'acceptance.t27')
  assert.ok(problems.some((problem) => /acceptance PASSED .*state blocked; expected BLOCKED/.test(problem)), problems.join('\n'))
})

test('queen-verdict measurements must equal the run verdict', async () => {
  const fields = await parsedFields()
  fields.MEASUREMENT_VALUES[1] = 'accepted'

  const problems = semanticProblems(fields, 'queen-verdict.t27')
  assert.ok(problems.some((problem) => /queen-verdict accepted .* verdict inconclusive/.test(problem)), problems.join('\n'))
})

test('an accepted Queen verdict requires a passed run', async () => {
  const fields = await parsedFields()
  fields.RUN_STATES_BY_ID[0] = 'failed'
  fields.RUN_VERDICTS[0] = 'accepted'
  fields.MEASUREMENT_VALUES[0] = 'FAILED'
  fields.MEASUREMENT_VALUES[1] = 'accepted'

  const problems = semanticProblems(fields, 'accepted-failed.t27')
  assert.ok(problems.some((problem) => /accepted verdict requires run state passed/.test(problem)), problems.join('\n'))
})

test('numeric measurements enforce the domain of their catalog unit', async (t) => {
  const cases = [
    ['elapsed', 'fast', 'ms'],
    ['cost', '-0.01', 'usd'],
    ['input-tokens', '1.5', 'tokens'],
    ['retries', '-3', 'count'],
    ['patch-lines', 'nine', 'lines'],
    ['jev-confidence', '1.1', 'probability'],
  ]

  for (const [key, value, unit] of cases) {
    await t.test(`${key} refuses ${value}`, async () => {
      const fields = await parsedFields()
      const existing = fields.MEASUREMENT_KEYS.indexOf(key)
      if (existing >= 0) fields.MEASUREMENT_VALUES[existing] = value
      else {
        appendMeasurement(fields, {
          runId: fields.RUN_IDS[0],
          key,
          value,
          unit,
          evidence: 'OBSERVED',
          source: 'numeric domain regression',
        })
      }

      const problems = semanticProblems(fields, `${key}.t27`)
      assert.ok(problems.some((problem) => problem.includes(`${key} value ${value} is invalid for unit ${unit}`)), problems.join('\n'))
    })
  }
})

test('zero and probability boundaries are valid measured values', async () => {
  const fields = await parsedFields()
  for (const [key, value, unit] of [
    ['cost', '0', 'usd'],
    ['input-tokens', '0', 'tokens'],
    ['jev-confidence', '1', 'probability'],
  ]) {
    appendMeasurement(fields, {
      runId: fields.RUN_IDS[0],
      key,
      value,
      unit,
      evidence: 'OBSERVED',
      source: 'numeric boundary evidence',
    })
  }

  assert.deepEqual(semanticProblems(fields, 'numeric-boundaries.t27'), [])
})

test('a complete experiment requires sealed baseline and JEV runs with both decision measurements', async () => {
  const fields = await parsedFields()
  fields.EXPERIMENT_STATES_BY_ID[0] = 'complete'
  appendRun(fields, {
    id: 't27-4328-bee-jev-pending',
    experimentId: fields.EXPERIMENT_IDS[0],
    configId: 'bee-jev',
    startedAt: '',
    finishedAt: '',
    state: 'pending',
    evidence: 'OBSERVED',
    verdict: 'not-reviewed',
    logSha: '',
    patchSha: '',
    artifactUrl: '',
    note: 'Waiting for credentials.',
  })

  const problems = semanticProblems(fields, 'complete.t27')
  assert.ok(problems.some((problem) => /complete experiment .* sealed bee-baseline run/.test(problem)), problems.join('\n'))
  assert.ok(problems.some((problem) => /complete experiment .* sealed bee-jev run/.test(problem)), problems.join('\n'))
})

test('blocked and inconclusive runs remain valid evidence while an experiment is not complete', async () => {
  const fields = await parsedFields()
  assert.equal(fields.RUN_STATES_BY_ID[0], 'blocked')
  assert.equal(fields.RUN_VERDICTS[0], 'inconclusive')
  assert.deepEqual(semanticProblems(fields, 'blocked.t27'), [])
})

test('blocked and inconclusive terminal runs cannot claim a complete comparison', async () => {
  const fields = await parsedFields()
  fields.EXPERIMENT_STATES_BY_ID[0] = 'complete'
  const runId = 't27-4328-bee-jev-blocked'
  appendRun(fields, {
    id: runId,
    experimentId: fields.EXPERIMENT_IDS[0],
    configId: 'bee-jev',
    startedAt: '2026-09-23T05:00:00Z',
    finishedAt: '2026-09-23T05:01:00Z',
    state: 'blocked',
    evidence: 'OBSERVED',
    verdict: 'inconclusive',
    logSha: '',
    patchSha: '',
    artifactUrl: '',
    note: 'Credential was unavailable.',
  })
  appendMeasurement(fields, {
    runId,
    key: 'acceptance',
    value: 'BLOCKED',
    unit: 'verdict',
    evidence: 'OBSERVED',
    source: 'credential preflight',
  })
  appendMeasurement(fields, {
    runId,
    key: 'queen-verdict',
    value: 'inconclusive',
    unit: 'verdict',
    evidence: 'OBSERVED',
    source: 'Queen review',
  })

  const problems = semanticProblems(fields, 'blocked-complete.t27')
  assert.ok(problems.some((problem) => /complete experiment .* sealed bee-baseline run/.test(problem)), problems.join('\n'))
  assert.ok(problems.some((problem) => /complete experiment .* sealed bee-jev run/.test(problem)), problems.join('\n'))
})

test('a comparison cannot complete with unknown model identity or unsealed arms', async () => {
  const fields = await parsedFields()
  fields.EXPERIMENT_STATES_BY_ID[0] = 'complete'
  fields.RUN_STATES_BY_ID[0] = 'passed'
  fields.RUN_VERDICTS[0] = 'accepted'
  fields.MEASUREMENT_VALUES[0] = 'PASSED'
  fields.MEASUREMENT_VALUES[1] = 'accepted'

  const runId = 't27-4328-bee-jev-failed'
  appendRun(fields, {
    id: runId,
    experimentId: fields.EXPERIMENT_IDS[0],
    configId: 'bee-jev',
    startedAt: '2026-09-23T05:00:00Z',
    finishedAt: '2026-09-23T05:01:00Z',
    state: 'failed',
    evidence: 'OBSERVED',
    verdict: 'rejected',
    logSha: '',
    patchSha: '',
    artifactUrl: '',
    note: 'Acceptance failed and Queen rejected the patch.',
  })
  appendMeasurement(fields, {
    runId,
    key: 'acceptance',
    value: 'FAILED',
    unit: 'verdict',
    evidence: 'OBSERVED',
    source: 'acceptance commands',
  })
  appendMeasurement(fields, {
    runId,
    key: 'queen-verdict',
    value: 'rejected',
    unit: 'verdict',
    evidence: 'OBSERVED',
    source: 'Queen review',
  })

  const problems = semanticProblems(fields, 'unsealed-complete.t27')
  assert.ok(problems.some((problem) => /explicit observed executor model/.test(problem)), problems.join('\n'))
  assert.ok(problems.some((problem) => /sealed bee-baseline run/.test(problem)), problems.join('\n'))
  assert.ok(problems.some((problem) => /sealed bee-jev run/.test(problem)), problems.join('\n'))
})

test('explicit model identity and sealed observed arms can complete a comparison', async () => {
  const fields = await parsedFields()
  fields.EXPERIMENT_STATES_BY_ID[0] = 'complete'
  fields.EXPERIMENT_EXECUTOR_MODELS[0] = 'gpt-test-fixed; reasoning=high'
  fields.EXPERIMENT_MODEL_EVIDENCE[0] = 'OBSERVED'
  fields.RUN_STATES_BY_ID[0] = 'passed'
  fields.RUN_EVIDENCE[0] = 'OBSERVED'
  fields.RUN_VERDICTS[0] = 'accepted'
  fields.RUN_LOG_SHAS[0] = 'a'.repeat(64)
  fields.RUN_ARTIFACT_URLS[0] = 'https://example.test/wars/baseline-log'
  fields.MEASUREMENT_VALUES[0] = 'PASSED'
  fields.MEASUREMENT_VALUES[1] = 'accepted'
  fields.MEASUREMENT_EVIDENCE[0] = 'OBSERVED'
  fields.MEASUREMENT_EVIDENCE[1] = 'OBSERVED'

  const runId = 't27-4328-bee-jev-failed-sealed'
  appendRun(fields, {
    id: runId,
    experimentId: fields.EXPERIMENT_IDS[0],
    configId: 'bee-jev',
    startedAt: '2026-09-23T05:00:00Z',
    finishedAt: '2026-09-23T05:01:00Z',
    state: 'failed',
    evidence: 'OBSERVED',
    verdict: 'rejected',
    logSha: 'b'.repeat(64),
    patchSha: 'c'.repeat(64),
    artifactUrl: 'https://example.test/wars/jev-log',
    note: 'Acceptance failed and Queen rejected the sealed patch.',
  })
  appendMeasurement(fields, {
    runId,
    key: 'acceptance',
    value: 'FAILED',
    unit: 'verdict',
    evidence: 'OBSERVED',
    source: 'sealed acceptance log',
  })
  appendMeasurement(fields, {
    runId,
    key: 'queen-verdict',
    value: 'rejected',
    unit: 'verdict',
    evidence: 'OBSERVED',
    source: 'sealed Queen review',
  })

  assert.deepEqual(semanticProblems(fields, 'sealed-complete.t27'), [])
})

test('non-ASCII source is refused by the L3 gate', async () => {
  const changed = source.replace('Queen WARS', 'Queen WARS \u2014')
  const out = await buildWars({ specText: changed, analyze })
  assert.equal(out.ts, null)
  assert.ok(out.problems.some((problem) => /non-ASCII/.test(problem)), out.problems.join('\n'))
})
