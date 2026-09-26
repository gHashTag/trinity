// Contract for the WARS arena. The experiment protocol and every result live in
// specs/queen/wars.t27; the UI and public files are projections, never another ledger.
import assert from 'node:assert/strict'
import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'

const ROOT = new URL('..', import.meta.url).pathname
const read = (rel) => readFileSync(join(ROOT, rel), 'utf8')
const mustExist = (rel) => assert.ok(existsSync(join(ROOT, rel)), `${rel} is missing`)

const SPEC = 'specs/queen/wars.t27'
const GENERATOR = 'scripts/queen-wars-from-spec.mjs'
const TS = 'src/lib/queenWars.generated.ts'
const JSON_OUT = 'public/queen/wars.json'
const PUBLIC_SPEC = 'public/queen/wars.t27'
const COMPONENT = 'src/components/QueenWars.tsx'
const CSS = 'src/components/QueenWars.css'

for (const file of [SPEC, GENERATOR, TS, JSON_OUT, PUBLIC_SPEC, COMPONENT, CSS]) mustExist(file)

const spec = read(SPEC)
assert.doesNotMatch(spec, /[^\x00-\x7f]/, 'the WARS .t27 source must remain ASCII/L3')
assert.match(spec, /pub const REAL_GITHUB_TASKS_ONLY : bool = true;/)
assert.match(spec, /pub const VARIABLE_FACTOR : str = "tri-decision-layer";/)
assert.match(spec, /pub const TRI_ROLE_EVIDENCE : str = "OBSERVED";/)
assert.match(spec, /https:\/\/docs\.typesafe\.ai\/introduction\/coding-agents/)
assert.match(spec, /https:\/\/github\.com\/gHashTag\/t27\/issues\/4328/)
assert.match(spec, /current process environment, GitHub Actions secret names, local Railway IaC, and local wrangler auth/)
assert.match(spec, /production Railway variables were not inspected/)
assert.match(spec, /pub const RUN_COUNT : u8 = \d+;/)
assert.match(spec, /pub const MEASUREMENT_COUNT : u8 = \d+;/)

const generated = JSON.parse(read(JSON_OUT))
assert.equal(generated.source.spec, SPEC)
assert.match(generated.source.sha256, /^[0-9a-f]{64}$/)
assert.deepEqual(generated.configurations.map((item) => item.id), ['bee-baseline', 'bee-jev', 'igla-coder', 'igla-race'])
assert.equal(generated.protocol.variableFactor, 'tri-decision-layer')
assert.equal(generated.protocol.triRoleEvidence, 'OBSERVED')
assert.match(generated.protocol.triRoleSource, /^https:\/\/t27\.ai\//)
assert.equal(generated.configurations[1].evidence, 'SOURCE-CLAIM')
assert.equal(generated.configurations[1].stateEvidence, 'OBSERVED')
assert.equal(generated.experiments[0].issue.url, 'https://github.com/gHashTag/t27/issues/4328')
assert.equal(generated.experiments[0].baseSha.length, 40)
assert.equal(generated.experiments[0].modelEvidence, 'UNKNOWN')
for (const measurement of generated.measurements) {
  assert.ok(measurement.source, `${measurement.runId}/${measurement.key} has evidence but no source`)
}

assert.equal(read(PUBLIC_SPEC), spec, 'public/queen/wars.t27 must be byte-identical to the source spec')

const hud = read('src/components/queenHud.ts')
assert.match(hud, /"wars"/)
assert.match(hud, /"KeyX"/)
const shell = read('src/pages/Queen.tsx')
assert.match(shell, /import \{ QueenWars \}/)
assert.match(shell, /view: "wars" as const/)
assert.match(shell, /boardView === "wars"/)
assert.match(shell, /warsView: "WARS"/)
assert.match(shell, /warsView: "ВОЙНЫ"/)

const component = read(COMPONENT)
assert.match(component, /QUEEN_WARS/)
assert.match(component, /const \[selectedExperimentId, setSelectedExperimentId\] = useState<string>\(QUEEN_WARS\.experiments\[0\]\.id\)/)
assert.match(component, /QUEEN_WARS\.experiments\.find\(\(item\) => item\.id === selectedExperimentId\)/)
assert.match(component, /<label htmlFor="queen-wars-experiment">/)
assert.match(component, /<select[\s\S]*?id="queen-wars-experiment"[\s\S]*?value=\{selectedExperimentId\}[\s\S]*?setSelectedExperimentId\(event\.currentTarget\.value\)/)
assert.match(component, /data-evidence=/)
assert.match(component, /data-outcome=/)
assert.match(component, /<details className="queen-wars-config-source" open>/)
assert.match(component, /config\.stateSource/)
assert.match(
  component,
  /run\?\.evidence \?\? config\.stateEvidence/,
  'a missing run must inherit the observed runtime-state evidence, not the capability claim',
)
assert.match(component, /experiment\.modelEvidence/)
assert.match(component, /<details className="queen-wars-measurement-source">/)
assert.match(component, /<summary>/)
assert.doesNotMatch(component, /title=\{config\.source\}/, 'configuration evidence must not be hidden in a pointer-only title')
assert.doesNotMatch(component, /title=\{value\?\.source/, 'measurement evidence must not be hidden in a pointer-only title')
assert.doesNotMatch(component, /target="_blank"/, 'WARS stays inside the single Queen game window')

const css = read(CSS)
assert.match(css, /@media \(prefers-reduced-motion: reduce\)/)
assert.match(css, /min-height: 44px/)
assert.match(css, /\[data-outcome="blocked"\]/)
assert.match(css, /\[data-evidence="SESSION-OBSERVED"\]/)
assert.match(css, /\.queen-wars-config-source > summary\s*\{[^}]*min-height:\s*44px;/s)
assert.match(css, /\.queen-wars-measurement-source > summary\s*\{[^}]*min-height:\s*44px;/s)
assert.match(css, /\.queen-wars-experiment-picker select\s*\{[^}]*min-height:\s*44px;/s)
assert.match(
  css,
  /\.queen-wars-arena[\s\S]*?container-type:\s*inline-size;/,
  'combatant lanes must react to their actual arena width, not the outer viewport',
)
assert.match(css, /@container wars-arena \(max-width: 1050px\)/)
assert.doesNotMatch(css, /font(?:-size)?\s*:[^;{}]*\b(?:8|9|10)px\b/, 'WARS technical text must be at least 11px')
assert.match(
  css,
  /\.queen-wars\s*\{[^}]*display:\s*block;/s,
  'the WARS scroll owner must reset the global flex section layout',
)
assert.match(
  css,
  /\.queen-wars-protocol,[\s\S]*?\.queen-wars-training\s*\{[^}]*flex:\s*0\s+0\s+auto;/,
  'nested WARS sections must not collapse inside the global flex section layout',
)

console.log(`queen-wars-contract: ${generated.configurations.length} configurations, ${generated.experiments.length} real experiment(s), ${generated.runs.length} run(s), ${generated.measurements.length} measurement(s); .t27 is authoritative`)
