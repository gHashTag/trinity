import { existsSync, readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { build } from 'esbuild'

const root = fileURLToPath(new URL('..', import.meta.url))
const queenPath = `${root}/src/pages/Queen.tsx`
const factoryPath = `${root}/src/components/QueenFactory.tsx`
const cityPath = `${root}/src/components/QueenResearchCity.tsx`
const modelPath = `${root}/src/components/queenResearchCityModel.ts`
const errors = []

function requirePattern(source, pattern, message) {
  if (!pattern.test(source)) errors.push(message)
}

const queen = readFileSync(queenPath, 'utf8')
const factory = readFileSync(factoryPath, 'utf8')

requirePattern(
  queen,
  /researchNodes=\{researchState\.data\?\.nodes\s*\?\?\s*\[\]\}/,
  'Factory must receive canonical live research nodes',
)
requirePattern(
  queen,
  /researchEdges=\{researchState\.data\?\.edges\s*\?\?\s*\[\]\}/,
  'Factory must receive canonical live research edges',
)
requirePattern(
  queen,
  /researchError=\{researchState\.error\}/,
  'Factory must receive the current research endpoint error separately',
)
requirePattern(
  factory,
  /<QueenResearchCity\b/,
  'Factory must render the research city',
)

if (!existsSync(cityPath)) {
  errors.push('src/components/QueenResearchCity.tsx is missing')
} else {
  const city = readFileSync(cityPath, 'utf8')
  requirePattern(city, /from\s+["']@react-three\/fiber["']/, 'City must use React Three Fiber')
  requirePattern(city, /frameloop=["']demand["']/, 'City canvas must render on demand')
  requirePattern(city, /dpr=\{\[1,\s*1\.5\]\}/, 'City canvas DPR must be capped at 1.5')
  requirePattern(city, /buildResearchCityModel\(/, 'City must use the executable live-graph model')
  requirePattern(city, /useReducedMotion\(/, 'City must read the reduced-motion preference')
  requirePattern(city, /data-motion=\{motionMode\}/, 'City must expose its effective motion mode')
  requirePattern(
    city,
    /enableDamping=\{motionMode\s*===\s*["']interactive["']\}/,
    'Reduced-motion mode must disable inertial camera damping',
  )
  requirePattern(city, /aria-pressed=/, 'City needs keyboard-operable DOM research controls')
  requirePattern(city, /selectedNode\.evidence/, 'City inspector must expose canonical evidence')
  if (/Math\.random|SAMPLE|FAKE|mock node|demo node/i.test(city)) {
    errors.push('City must not invent random, sample, fake, mock, or demo nodes')
  }
  if (/fpga.{0,20}(online|connected)|device.{0,20}(online|connected)/i.test(city)) {
    errors.push('City must not claim connected hardware without a hardware registry')
  }
}

if (!existsSync(modelPath)) {
  errors.push('src/components/queenResearchCityModel.ts is missing')
} else {
  try {
    const bundled = await build({
      entryPoints: [modelPath],
      bundle: true,
      format: 'esm',
      platform: 'node',
      write: false,
      logLevel: 'silent',
    })
    const source = bundled.outputFiles[0].text
    const model = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`)
    const nodes = [
      { id: 'core', label: 'Core', layer: 'core', maturity: 'shipped', state: 'researched', evidence: 'core evidence' },
      { id: 'silicon', label: 'Silicon', layer: 'silicon', maturity: 'blocked', state: 'locked', evidence: 'simulation only' },
    ]
    const edges = [{ from: 'core', to: 'silicon' }]
    const live = model.buildResearchCityModel(nodes, edges, ['core'], null)
    const offline = model.buildResearchCityModel(nodes, edges, ['core'], 'endpoint unavailable')

    if (!live.available) errors.push('Executable city model rejected a valid graph')
    if (!live.layers.includes('silicon')) errors.push('City model must close missing graph layers from canonical nodes')
    if (live.positions.size !== 2) errors.push('Every canonical node must receive a laboratory position')
    if (live.routes.length !== 1) errors.push('Every valid canonical edge must receive an energy route')
    if (offline.available || offline.positions.size || offline.routes.length) {
      errors.push('Endpoint failure must suppress stale laboratories and routes')
    }
    if (model.motionModeFromPreference(true) !== 'static') {
      errors.push('Reduced-motion preference must select static mode')
    }
    if (model.motionModeFromPreference(false) !== 'interactive') {
      errors.push('Default motion preference must retain interactive mode')
    }

    const malformedCases = [
      { name: 'null node', nodes: [null], edges: [] },
      { name: 'empty node id', nodes: [{ ...nodes[0], id: '' }], edges: [] },
      { name: 'missing node label', nodes: [{ ...nodes[0], label: undefined }], edges: [] },
      { name: 'unknown research state', nodes: [{ ...nodes[0], state: 'bogus' }], edges: [] },
      { name: 'null edge', nodes, edges: [null] },
      { name: 'missing edge target', nodes, edges: [{ from: 'core' }] },
      { name: 'unknown edge endpoint', nodes, edges: [{ from: 'core', to: 'missing' }] },
    ]
    for (const malformed of malformedCases) {
      try {
        const result = model.buildResearchCityModel(malformed.nodes, malformed.edges, ['core'], null)
        if (result.available || result.positions.size || result.routes.length) {
          errors.push(`Malformed ${malformed.name} must fail closed without geometry`)
        }
      } catch (error) {
        errors.push(`Malformed ${malformed.name} must not throw: ${error instanceof Error ? error.message : error}`)
      }
    }
  } catch (error) {
    errors.push(`Executable city model failed: ${error instanceof Error ? error.message : error}`)
  }
}

if (errors.length) {
  errors.forEach((error) => console.error(`Queen research city contract: ${error}`))
  process.exitCode = 1
} else {
  console.log('Queen research city contract: PASS (executable graph/outage/motion model + source wiring)')
}
