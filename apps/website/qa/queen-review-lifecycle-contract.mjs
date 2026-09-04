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
  derived.reconciliationAnomaly !== 1
) {
  errors.push(`derived queue counts are wrong (an absent field is not an anomaly): ${JSON.stringify(derived)}`)
}
const unclassifiedOf = (board) => (typeof lifecycle.reviewUnclassified === 'function' ? lifecycle.reviewUnclassified(board) : NaN)
if (unclassifiedOf({ cards }) !== 1) {
  errors.push('one review card without reviewState must count as unclassified')
}
if (lifecycle.reviewStateOf({ column: 'review' }) !== null) {
  errors.push('an ownerless review card reads absent (null), never an anomaly the wire did not state')
}
if (lifecycle.reviewStateOf({ column: 'review', reviewState: 'not-a-state' }) !== null) {
  errors.push('an unknown wire state reads absent, never a label')
}
// The live ledger on 2026-09-04: every review card lacks the field. No
// queue may then read 0 - that is the false counter this screen exists to
// avoid - so every count is null and the unclassified total carries the fact.
const absent = { cards: [{ column: 'review' }, { column: 'review' }, { column: 'done' }] }
const absentCounts = lifecycle.reviewCounts(absent)
if (Object.values(absentCounts).some((count) => count !== null)) {
  errors.push(`when no review card carries reviewState every queue is null: ${JSON.stringify(absentCounts)}`)
}
if (unclassifiedOf(absent) !== 2) {
  errors.push('the unclassified total is the number of review cards without the field')
}
if (Object.values(lifecycle.reviewCounts(null)).some((count) => count !== null)) {
  errors.push('a missing board reads null in every queue, not 0')
}
const emptyColumn = lifecycle.reviewCounts({ cards: [{ column: 'done' }] })
if (Object.values(emptyColumn).some((count) => count !== 0)) {
  errors.push('an empty review column is an honest 0 in every queue')
}
requirePattern(
  /reviewQueueCounts\[reviewState\] \?\? "—"/,
  'the REVIEW QUEUE menu prints a dash for a null queue count',
)
requirePattern(
  /reviewUnclassified\(board\)/,
  'the REVIEW QUEUE menu carries the unclassified total',
)
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
if (!/[А-Яа-яЁё]/.test(lifecycle.publicIssueTitle('A long English-only issue title from GitHub', 42, 'ru'))) {
  errors.push('Russian mode must fail closed with a Russian linked placeholder')
}
if (!/[А-Яа-яЁё]/.test(lifecycle.publicResearchText('English research title', 'core-1', 'ru', 'label'))) {
  errors.push('Russian mode must fail closed on English-only research labels')
}
if (/[А-Яа-яЁё]/.test(lifecycle.publicResearchText('Русское описание', 'core-1', 'en'))) {
  errors.push('English mode must fail closed on Russian research details')
}
if (lifecycle.publicResearchText('Русская технология', 'core-1', 'ru', 'label') !== 'Русская технология') {
  errors.push('Russian mode must preserve localized research labels')
}

if (errors.length) {
  errors.forEach((error) => console.error(`Queen review lifecycle: ${error}`))
  process.exitCode = 1
} else {
  console.log('Queen review lifecycle: PASS (truthful owner and action queues)')
}
