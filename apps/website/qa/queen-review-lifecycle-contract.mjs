import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import ts from 'typescript'

const root = fileURLToPath(new URL('..', import.meta.url))
const queen = readFileSync(`${root}/src/pages/Queen.tsx`, 'utf8')
const lifecycleSource = readFileSync(
  `${root}/src/pages/queenReviewLifecycle.ts`,
  'utf8',
)
const lifecycleJs = ts.transpileModule(lifecycleSource, {
  compilerOptions: {
    module: ts.ModuleKind.ES2022,
    target: ts.ScriptTarget.ES2022,
  },
}).outputText
const lifecycle = await import(
  `data:text/javascript;base64,${Buffer.from(lifecycleJs).toString('base64')}`
)
const errors = []

function requirePattern(pattern, message) {
  if (!pattern.test(queen)) errors.push(message)
}

requirePattern(
  /from "\.\/queenReviewLifecycle"/,
  'Queen must consume the executable review lifecycle model',
)
requirePattern(
  /reviewQueues\?:\s*Record<QueenReviewState, number>/,
  'QueenBoard must consume the backend reviewQueues ledger',
)
requirePattern(
  /reviewStateOf\(card\)/,
  'Review cards must be classified by lifecycle state',
)
requirePattern(
  /queenReviewPending:\s*"Queen review pending"/,
  'English Queen-review label is missing',
)
requirePattern(
  /changesRequested:\s*"Changes requested"/,
  'English changes-requested label is missing',
)
requirePattern(
  /humanEscalation:\s*"Human escalation"/,
  'English escalation label is missing',
)
requirePattern(
  /reconciliationAnomaly:\s*"Ledger anomaly"/,
  'English reconciliation label is missing',
)
requirePattern(
  /queenReviewPending:\s*"Ревью Queen"/,
  'Russian Queen-review label is missing',
)
requirePattern(
  /changesRequested:\s*"Нужны изменения"/,
  'Russian changes-requested label is missing',
)
requirePattern(
  /humanEscalation:\s*"Решение человека"/,
  'Russian escalation label is missing',
)
requirePattern(
  /reconciliationAnomaly:\s*"Аномалия реестра"/,
  'Russian reconciliation label is missing',
)

if (/reviewCards\.length[\s\S]{0,80}c\.reviewing/.test(queen)) {
  errors.push('The total review column must not be labelled as Queen review debt')
}

const cards = [
  { column: 'review', reviewState: 'queenReviewPending' },
  { column: 'review', reviewState: 'changesRequested' },
  { column: 'review', reviewState: 'humanEscalation' },
  { column: 'review', reviewState: 'reconciliationAnomaly' },
  { column: 'review' },
  { column: 'running', reviewState: 'queenReviewPending' },
]
const derived = lifecycle.reviewCounts({ cards })
if (
  derived.queenReviewPending !== 1 ||
  derived.changesRequested !== 1 ||
  derived.humanEscalation !== 1 ||
  derived.reconciliationAnomaly !== 2
) {
  errors.push(`derived queue counts are wrong: ${JSON.stringify(derived)}`)
}
if (lifecycle.reviewStateOf({ column: 'review' }) !== 'reconciliationAnomaly') {
  errors.push('a legacy ownerless review card must fail visibly to anomaly')
}
const published = {
  queenReviewPending: 4,
  changesRequested: 3,
  humanEscalation: 2,
  reconciliationAnomaly: 1,
}
const fromLedger = lifecycle.reviewCounts({ cards: [], reviewQueues: published })
if (fromLedger !== published) {
  errors.push('the additive backend reviewQueues ledger must remain authoritative')
}

const legacyRussianTitle = 'Старый issue до языковой политики'
if (/[А-Яа-яЁё]/.test(lifecycle.publicIssueTitle(legacyRussianTitle, 42, 'en'))) {
  errors.push('English mode must fail closed on a legacy non-English GitHub title')
}
if (lifecycle.publicIssueTitle(legacyRussianTitle, 42, 'ru') !== legacyRussianTitle) {
  errors.push('Russian mode must preserve the canonical legacy GitHub title')
}
if (lifecycle.publicIssueTitle('English issue title', 42, 'en') !== 'English issue title') {
  errors.push('English mode must preserve a compliant GitHub title')
}

if (errors.length) {
  errors.forEach((error) => console.error(`Queen review lifecycle: ${error}`))
  process.exitCode = 1
} else {
  console.log('Queen review lifecycle: PASS (truthful owner and action queues)')
}
