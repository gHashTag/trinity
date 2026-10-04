import { readFileSync } from 'node:fs'
import ts from 'typescript'

const CYRILLIC = /[\u0400-\u04ff]/
const REQUIRED_AGENT_KEYS = [
  'copyAgent',
  'copiedAgent',
  'copyFailed',
  'copyAgentTitle',
  'copyAgentCopy',
]

function propertyName(node) {
  if (ts.isIdentifier(node) || ts.isStringLiteral(node)) return node.text
  throw new Error('COPY contains a computed property; locale keys must be static')
}

function objectLiteral(node) {
  let current = node
  while (
    ts.isAsExpression(current) ||
    ts.isSatisfiesExpression(current) ||
    ts.isParenthesizedExpression(current)
  ) {
    current = current.expression
  }
  return ts.isObjectLiteralExpression(current) ? current : undefined
}

export function extractCopy(source) {
  const file = ts.createSourceFile(
    'Queen.tsx',
    source,
    ts.ScriptTarget.Latest,
    true,
    ts.ScriptKind.TSX,
  )
  let copyObject
  for (const statement of file.statements) {
    if (!ts.isVariableStatement(statement)) continue
    for (const declaration of statement.declarationList.declarations) {
      if (
        ts.isIdentifier(declaration.name) &&
        declaration.name.text === 'COPY' &&
        declaration.initializer
      ) {
        copyObject = objectLiteral(declaration.initializer)
      }
    }
  }
  if (!copyObject) throw new Error('Queen.tsx must define a static COPY object')

  const locales = new Map()
  for (const localeProperty of copyObject.properties) {
    if (!ts.isPropertyAssignment(localeProperty)) continue
    const locale = propertyName(localeProperty.name)
    const localeObject = objectLiteral(localeProperty.initializer)
    if (!localeObject) {
      throw new Error(`COPY.${locale} must be a static object`)
    }
    const values = new Map()
    for (const property of localeObject.properties) {
      if (!ts.isPropertyAssignment(property)) continue
      const key = propertyName(property.name)
      if (!ts.isStringLiteralLike(property.initializer)) {
        throw new Error(`COPY.${locale}.${key} must be a static string`)
      }
      values.set(key, property.initializer.text)
    }
    locales.set(locale, values)
  }
  return locales
}

export function validateCopy(locales) {
  const errors = []
  const en = locales.get('en')
  const ru = locales.get('ru')
  if (!en) errors.push('COPY.en is missing')
  if (!ru) errors.push('COPY.ru is missing')
  if (!en || !ru) return errors

  const enKeys = [...en.keys()].sort()
  const ruKeys = [...ru.keys()].sort()
  const missingRU = enKeys.filter((key) => !ru.has(key))
  const missingEN = ruKeys.filter((key) => !en.has(key))
  if (missingRU.length) errors.push(`COPY.ru is missing: ${missingRU.join(', ')}`)
  if (missingEN.length) errors.push(`COPY.en is missing: ${missingEN.join(', ')}`)

  for (const key of REQUIRED_AGENT_KEYS) {
    if (!en.has(key) || !ru.has(key)) errors.push(`A2A copy key is missing: ${key}`)
  }
  for (const [key, value] of en) {
    if (CYRILLIC.test(value)) errors.push(`COPY.en.${key} contains Cyrillic`)
    if (!value.trim()) errors.push(`COPY.en.${key} is empty`)
  }
  for (const [key, value] of ru) {
    if (!value.trim()) errors.push(`COPY.ru.${key} is empty`)
  }

  const translated = [...ru.values()].filter((value) => CYRILLIC.test(value)).length
  if (translated * 2 < ru.size) {
    errors.push(`COPY.ru has Cyrillic in only ${translated}/${ru.size} values`)
  }
  return errors
}

function selfTest() {
  const valid = new Map([
    ['en', new Map(REQUIRED_AGENT_KEYS.map((key) => [key, `English ${key}`]))],
    ['ru', new Map(REQUIRED_AGENT_KEYS.map((key) => [key, `\u041F\u0435\u0440\u0435\u0432\u043E\u0434 ${key}`]))],
  ])
  if (validateCopy(valid).length) throw new Error('self-test rejected matching locales')

  const missing = new Map([
    ['en', new Map(valid.get('en'))],
    ['ru', new Map([...valid.get('ru')].slice(1))],
  ])
  if (!validateCopy(missing).some((error) => error.includes('missing'))) {
    throw new Error('self-test did not detect a missing Russian key')
  }

  const leaked = new Map([
    ['en', new Map(valid.get('en'))],
    ['ru', new Map(valid.get('ru'))],
  ])
  leaked.get('en').set('copyAgent', '\u0420\u0443\u0441\u0441\u043A\u0438\u0439 leak')
  if (!validateCopy(leaked).some((error) => error.includes('Cyrillic'))) {
    throw new Error('self-test did not detect Cyrillic in English copy')
  }
}

selfTest()
const source = readFileSync(new URL('../src/pages/Queen.tsx', import.meta.url), 'utf8')
const locales = extractCopy(source)
const errors = validateCopy(locales)
if (errors.length) {
  errors.forEach((error) => console.error(`Queen language contract: ${error}`))
  process.exitCode = 1
} else {
  console.log(
    `Queen language contract: PASS (${locales.get('en').size} EN keys, ${locales.get('ru').size} RU keys)`,
  )
}
