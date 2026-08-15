import { readFileSync } from 'node:fs'
import { collectRouteText, ROUTES } from './browser-audit.mjs'

export const CYRILLIC = /[А-Яа-яЁё]/
export function hasCyrillic(text) { return CYRILLIC.test(text) }

export function selfTest() {
  if (!hasCyrillic('Проверка')) throw new Error('самотест: кириллица не распознана')
  if (hasCyrillic('English text')) throw new Error('самотест: латиница ошибочно распознана')
  if (ROUTES.length < 25 || !ROUTES.includes('queen') || !ROUTES.includes('canvas'))
    throw new Error('самотест: список маршрутов не покрывает новые страницы')
  console.log('самотест EN-аудитора: PASS')
}

if (process.argv.includes('--selftest')) selfTest()
else {
  const exceptions = JSON.parse(readFileSync(new URL('./language-exceptions.json', import.meta.url), 'utf8')).en
  const baseUrl = process.env.AUDIT_BASE_URL || 'http://127.0.0.1:4173/index.html?lang=en'
  try {
    const pages = await collectRouteText('en', baseUrl)
    const findings = []
    for (const route of ROUTES) {
      const ignored = exceptions[route] || []
      for (const line of pages[route].split(/\n+/).map(s => s.trim()).filter(Boolean)) {
        if (hasCyrillic(line) && !ignored.some(pattern => line.includes(pattern)))
          findings.push(`/${route || '(главная)'}: ${line.slice(0, 180)}`)
      }
    }
    if (findings.length) {
      console.error(`EN-аудит: найдено строк с кириллицей: ${findings.length}`)
      findings.forEach(line => console.error(`  ${line}`))
      process.exitCode = 1
    } else console.log(`EN-аудит: PASS (${ROUTES.length} маршрутов)`)
  } catch (error) {
    console.error(`EN-аудит не запущен: ${error.message}`)
    process.exitCode = 1
  }
}
