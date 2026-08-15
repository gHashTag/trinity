import { readFileSync } from 'node:fs'
import { collectRouteText, ROUTES } from './browser-audit.mjs'

export const CYRILLIC = /[А-Яа-яЁё]/
export const ENGLISH_LINE = /[A-Za-z]{4}\s+[A-Za-z]{3,}\s+[A-Za-z]{3,}/
export function hasCyrillic(text) { return CYRILLIC.test(text) }
export function isEnglishOnlyCandidate(text) {
  return text.length > 45 && ENGLISH_LINE.test(text) && !hasCyrillic(text)
}
export function isException(route, line, exceptions) {
  return (exceptions[route] || []).some(pattern => line.includes(pattern))
}

export function selfTest() {
  if (!hasCyrillic('Русская строка')) throw new Error('самотест: кириллица не распознана')
  if (hasCyrillic('English text only')) throw new Error('самотест: латиница ошибочно распознана')
  if (!isEnglishOnlyCandidate('This is an English sentence that must be found'))
    throw new Error('самотест: английская строка не распознана')
  if (isEnglishOnlyCandidate('Это русская строка с достаточной длиной для проверки'))
    throw new Error('самотест: русская строка ошибочно признана английской')
  const known = { verification: ['Hamlet & Taylor'] }
  if (!isException('verification', 'Hamlet & Taylor, “Partition Testing Does Not Inspire Confidence”', known))
    throw new Error('самотест: исключение библиографии не работает')
  if (isException('verification', 'A new English sentence must not be silently ignored', known))
    throw new Error('самотест: исключение слишком широкое')
  console.log('самотест RU-аудитора: PASS')
}

if (process.argv.includes('--selftest')) selfTest()
else {
  const allExceptions = JSON.parse(readFileSync(new URL('./language-exceptions.json', import.meta.url), 'utf8'))
  const exceptions = allExceptions.ru
  const baseUrl = process.env.AUDIT_BASE_URL || 'http://127.0.0.1:4173/index.html?lang=ru'
  try {
    const pages = await collectRouteText('ru', baseUrl)
    const findings = []
    for (const route of ROUTES) {
      for (const line of pages[route].split(/\n+/).map(s => s.trim()).filter(Boolean)) {
        if (isEnglishOnlyCandidate(line) && !isException(route, line, exceptions))
          findings.push(`/${route || '(главная)'}: ${line.slice(0, 180)}`)
      }
    }
    if (findings.length) {
      console.error(`RU-аудит: найдено английских строк: ${findings.length}`)
      findings.forEach(line => console.error(`  ${line}`))
      process.exitCode = 1
    } else console.log(`RU-аудит: PASS (${ROUTES.length} маршрутов)`)
  } catch (error) {
    console.error(`RU-аудит не запущен: ${error.message}`)
    process.exitCode = 1
  }
}
