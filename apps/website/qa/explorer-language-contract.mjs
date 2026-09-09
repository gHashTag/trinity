// Every Explorer page carries its own two-language dictionary, and this is the
// gate that keeps the pair honest.
//
// The pages render their own chrome instead of <Navigation>, so the site's
// message catalogues do not cover them: the copy lives in a local `UI = {en,
// ru}` literal. That is fine, and it is exactly the thing that rots — one
// locale gains a key, the other does not, and a Russian reader meets an English
// sentence nobody notices because the page still renders.
//
// Four checks, all static (no browser, no build): both locales exist, their key
// sets are identical, no English dictionary smuggles Cyrillic, and the Russian
// one is actually Russian rather than a copy of the English.

import { readFileSync } from 'node:fs'
import ts from 'typescript'

const CYRILLIC = /[Ѐ-ӿ]/
const LATIN_WORD = /[A-Za-z]{3,}/

const PAGES = [
  'src/pages/SpecExplorer.tsx',
  'src/pages/SkillExplorer.tsx',
  'src/pages/CronExplorer.tsx',
  'src/pages/AgentExplorer.tsx',
  'src/pages/ToolExplorer.tsx',
  'src/pages/SystemDocs.tsx',
  'src/pages/ClientsConsole.tsx',
]

/**
 * Values that are allowed to be identical in both locales, or to look English
 * in the Russian dictionary: proper nouns and file names carry no translation.
 */
const NEUTRAL = new Set(['SKILL.md', 'Inngest', 'GitHub Actions', 'Telegram', 'SOUL.md', 'AGENTS.md'])

/** AST, HIR, UTC, DNS: an acronym is the same word in both languages. */
function isAcronym(value) {
  return /^[A-Z0-9./ ()-]{2,12}$/.test(value.trim())
}

function propertyName(node) {
  if (ts.isIdentifier(node) || ts.isStringLiteral(node)) return node.text
  throw new Error('a computed property: locale keys must be static')
}

function unwrap(node) {
  let current = node
  while (ts.isAsExpression(current) || ts.isSatisfiesExpression(current) || ts.isParenthesizedExpression(current)) {
    current = current.expression
  }
  return ts.isObjectLiteralExpression(current) ? current : undefined
}

/** The local `UI = { en: {...}, ru: {...} }` literal, as a Map of Maps. */
export function extractUi(source, file) {
  const parsed = ts.createSourceFile(file, source, ts.ScriptTarget.Latest, true, ts.ScriptKind.TSX)
  let object
  for (const statement of parsed.statements) {
    if (!ts.isVariableStatement(statement)) continue
    for (const declaration of statement.declarationList.declarations) {
      if (ts.isIdentifier(declaration.name) && declaration.name.text === 'UI' && declaration.initializer) {
        object = unwrap(declaration.initializer)
      }
    }
  }
  if (!object) throw new Error(`${file} must define a static UI object`)

  const locales = new Map()
  for (const localeProperty of object.properties) {
    if (!ts.isPropertyAssignment(localeProperty)) continue
    const locale = propertyName(localeProperty.name)
    const localeObject = unwrap(localeProperty.initializer)
    if (!localeObject) throw new Error(`${file}: UI.${locale} must be a static object`)
    const values = new Map()
    for (const property of localeObject.properties) {
      if (!ts.isPropertyAssignment(property)) continue
      const key = propertyName(property.name)
      if (!ts.isStringLiteralLike(property.initializer)) {
        throw new Error(`${file}: UI.${locale}.${key} must be a static string`)
      }
      values.set(key, property.initializer.text)
    }
    locales.set(locale, values)
  }
  return locales
}

export function validate(file, locales) {
  const errors = []
  const en = locales.get('en')
  const ru = locales.get('ru')
  if (!en) errors.push(`${file}: UI.en is missing`)
  if (!ru) errors.push(`${file}: UI.ru is missing`)
  if (!en || !ru) return errors

  for (const key of en.keys()) if (!ru.has(key)) errors.push(`${file}: UI.ru is missing the key ${key}`)
  for (const key of ru.keys()) if (!en.has(key)) errors.push(`${file}: UI.en is missing the key ${key}`)

  for (const [key, value] of en) {
    if (CYRILLIC.test(value)) errors.push(`${file}: UI.en.${key} contains Cyrillic`)
  }

  let translated = 0
  let comparable = 0
  for (const [key, value] of ru) {
    const english = en.get(key)
    if (english === undefined) continue
    if (NEUTRAL.has(value.trim()) || isAcronym(value)) continue
    // A value with no letters at all (a glyph, a number, punctuation) is the
    // same in every language and proves nothing either way.
    if (!LATIN_WORD.test(english)) continue
    comparable += 1
    if (CYRILLIC.test(value)) translated += 1
    else if (value === english && LATIN_WORD.test(value)) {
      errors.push(`${file}: UI.ru.${key} is the English string verbatim`)
    }
  }
  if (comparable > 0 && translated / comparable < 0.8) {
    errors.push(`${file}: only ${translated} of ${comparable} Russian values are actually in Russian`)
  }
  return errors
}

const failures = []
for (const file of PAGES) {
  try {
    failures.push(...validate(file, extractUi(readFileSync(file, 'utf8'), file)))
  } catch (error) {
    failures.push(`${file}: ${error.message}`)
  }
}

if (failures.length) {
  for (const failure of failures) console.error(`  ${failure}`)
  console.error(`Explorer languages: FAIL (${failures.length})`)
  process.exit(1)
}
console.log(`Explorer languages: PASS (${PAGES.length} pages, en/ru key sets identical)`)
