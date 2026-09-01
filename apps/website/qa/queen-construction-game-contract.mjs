import { existsSync, readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { build } from 'esbuild'

const root = fileURLToPath(new URL('..', import.meta.url))
const cityPath = `${root}/src/components/QueenResearchCity.tsx`
const modelPath = `${root}/src/components/queenConstructionModel.ts`
const errors = []

function requirePattern(source, pattern, message) {
  if (!pattern.test(source)) errors.push(message)
}

if (!existsSync(modelPath)) {
  errors.push('Construction model is missing')
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
      { id: 'seed', label: 'Seed', layer: 'seed', maturity: 'shipped', state: 'researched', evidence: 'seed proof' },
      { id: 'ring', label: 'Ring', layer: 'ring', maturity: 'partial', state: 'researching', evidence: 'ring proof' },
      { id: 'next', label: 'Next', layer: 'ring', maturity: 'planned', state: 'available', evidence: 'next contract' },
      { id: 'sealed', label: 'Sealed', layer: 'silicon', maturity: 'blocked', state: 'locked', evidence: 'blocked' },
    ]
    const edges = [
      { from: 'seed', to: 'ring' },
      { from: 'ring', to: 'next' },
      { from: 'next', to: 'sealed' },
    ]
    const plan = model.buildConstructionPlan(nodes, edges, null)
    if (!plan.available) errors.push('Valid research graph must produce a construction plan')
    if (plan.structures.length !== 4) errors.push('Every research node must produce one structure')
    if (plan.structures.find((item) => item.id === 'seed')?.stage !== 'complete') errors.push('Researched nodes must be complete')
    if (plan.structures.find((item) => item.id === 'ring')?.stage !== 'assembling') errors.push('Researching nodes must be assembling')
    if (plan.structures.find((item) => item.id === 'next')?.stage !== 'blueprint') errors.push('Available nodes must be blueprints')
    if (plan.structures.find((item) => item.id === 'sealed')?.stage !== 'sealed') errors.push('Locked nodes must remain sealed')
    if (plan.routes.length !== 3) errors.push('Every dependency must produce one logistics route')
    if (plan.summary.complete !== 1 || plan.summary.assembling !== 1 || plan.summary.blueprint !== 1 || plan.summary.sealed !== 1) {
      errors.push('Construction summary must derive from canonical research states')
    }
    const next = plan.structures.find((item) => item.id === 'next')
    if (next?.dependenciesReady !== 0 || next?.dependenciesTotal !== 1) {
      errors.push('Dependency readiness must count only completed prerequisites')
    }
    const offline = model.buildConstructionPlan(nodes, edges, 'endpoint unavailable')
    if (offline.available || offline.structures.length || offline.routes.length) {
      errors.push('Endpoint failure must suppress the construction plan')
    }
    const malformed = model.buildConstructionPlan([null], [], null)
    if (malformed.available || malformed.structures.length) {
      errors.push('Malformed graph input must fail closed')
    }
  } catch (error) {
    errors.push(`Executable construction model failed: ${error instanceof Error ? error.message : error}`)
  }
}

if (!existsSync(cityPath)) {
  errors.push('Research City component is missing')
} else {
  const city = readFileSync(cityPath, 'utf8')
  requirePattern(city, /<instancedMesh\b/, 'Laboratory foundations must use instanced rendering')
  requirePattern(city, /buildConstructionPlan\(/, 'City must consume the executable construction plan')
  requirePattern(city, /queen27-city-build-queue/, 'City must expose a native construction queue')
  requirePattern(city, /aria-pressed=/, 'Construction selection must be keyboard operable')
  requirePattern(city, /CONSTRUCTION_FPS\s*=\s*12/, 'Interactive construction rendering must be capped at 12 FPS')
  if (/Math\.random|fictional resource|ore count/i.test(city)) {
    errors.push('Construction UI must not invent resources or random progress')
  }
}

if (errors.length) {
  errors.forEach((error) => console.error(`Queen construction game contract: ${error}`))
  process.exitCode = 1
} else {
  console.log('Queen construction game contract: PASS (state mapping, dependency logistics, instancing, bounded animation)')
}
