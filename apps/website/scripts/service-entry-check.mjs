import { readFileSync } from 'node:fs'

const root = new URL('..', import.meta.url)
const component = readFileSync(new URL('src/components/ServiceEntry.tsx', root), 'utf8')
const app = readFileSync(new URL('src/App.tsx', root), 'utf8')

const requirements = [
  ['official Telegram bot URL', component.includes('https://t.me/t27ai_bot?start=website')],
  ['English Telegram CTA', component.includes('Open in Telegram')],
  ['Russian Telegram CTA', component.includes('Открыть в Telegram')],
  ['English verified-profile explanation', component.includes('verified Telegram profile')],
  ['Russian verified-profile explanation', component.includes('подтверждённого профиля Telegram')],
  ['browser CTA uses native disabled semantics', component.includes('<button type="button" className="btn secondary" disabled')],
  ['browser CTA has no URL constant', !component.includes('BROWSER_URL')],
  ['no embedded Mini App URL', !component.includes('startapp=')],
  ['safe external-link attributes', component.includes('rel="noopener noreferrer"')],
  ['homepage placement', app.includes('<ServiceEntry />')],
]

const failed = requirements.filter(([, ok]) => !ok)
if (failed.length) {
  for (const [name] of failed) console.error(`FAIL: ${name}`)
  process.exit(1)
}

console.log(`PASS: ${requirements.length} service-entry requirements`)
