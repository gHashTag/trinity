import { existsSync, readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

const root = fileURLToPath(new URL('..', import.meta.url))
const queenPath = `${root}/src/pages/Queen.tsx`
const factoryPath = `${root}/src/components/QueenFactory.tsx`

const queen = readFileSync(queenPath, 'utf8')
const errors = []

function requirePattern(source, pattern, message) {
  if (!pattern.test(source)) errors.push(message)
}

requirePattern(
  queen,
  /useState<\s*"kanban"\s*\|\s*"map"\s*\|\s*"factory"(\s*\|\s*"[a-z]+")*\s*>/,
  'Queen board modes must include factory',
)
requirePattern(queen, /factoryView:\s*"FACTORY"/, 'English Factory label is missing')
requirePattern(queen, /factoryView:\s*"ФАБРИКА"/, 'Russian Factory label is missing')
requirePattern(queen, /<QueenFactory\b/, 'Queen must render the real factory component')
requirePattern(
  queen,
  /workers=\{researchState\.data\?\.workers\s*\?\?\s*null\}/,
  'Factory must receive the public worker ledger',
)
requirePattern(
  queen,
  /cards=\{boardState\.data\?\.cards\s*\?\?\s*\[\]\}/,
  'Factory must receive the public board cards',
)

if (!existsSync(factoryPath)) {
  errors.push('src/components/QueenFactory.tsx is missing')
} else {
  const factory = readFileSync(factoryPath, 'utf8')
  requirePattern(
    factory,
    /columns\.map\(/,
    'Factory stations must come from the live board columns',
  )
  requirePattern(
    factory,
    /cards\.filter\(/,
    'Factory modules must come from the live board cards',
  )
  requirePattern(
    factory,
    /effectiveWorkers\.slots\.map\(/,
    'Factory hangars must come from the public worker slots',
  )
  requirePattern(
    factory,
    /const effectiveWorkers = researchError \? null : workers/,
    'Factory must suppress stale worker slots when research telemetry fails',
  )
  requirePattern(
    factory,
    /https:\/\/github\.com\/\$\{repo\}\/issues\/\$\{card\.number\}/,
    'Factory modules must link to canonical GitHub issues',
  )
  if (/Math\.random|FALLBACK_TASK|SAMPLE_TASK|fake task/i.test(factory)) {
    errors.push('Factory must not invent sample, fallback, random, or fake tasks')
  }
}

if (errors.length) {
  errors.forEach((error) => console.error(`Queen factory contract: ${error}`))
  process.exitCode = 1
} else {
  console.log('Queen factory contract: PASS (live cards, workers, and issue links)')
}
