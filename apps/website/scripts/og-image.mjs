// Render public/og-image.png -- the picture a link to t27.ai shows -- from
// og/og-image.svg, with any headless Chromium, so the text is drawn in the
// site's own font (public/fonts) rather than whatever the renderer has.
//
//   node scripts/og-image.mjs              # finds a Chromium
//   CHROME=/path/to/chromium node scripts/og-image.mjs
//
// qa/og-preview-contract.mjs checks the words in the SVG against the page and
// the size of the PNG; it does not render, so CI needs no browser.

import { spawn } from 'node:child_process'
import { existsSync, mkdtempSync, readFileSync, rmSync, statSync } from 'node:fs'
import { tmpdir } from 'node:os'
import path from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'

const here = path.dirname(fileURLToPath(import.meta.url))
const svg = path.resolve(here, '../og/og-image.svg')
const png = path.resolve(here, '../public/og-image.png')

const chrome = [
  process.env.CHROME,
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/Applications/Chromium.app/Contents/MacOS/Chromium',
  '/Applications/BrowserOS.app/Contents/MacOS/BrowserOS',
  '/usr/bin/chromium',
  '/usr/bin/chromium-browser',
  '/usr/bin/google-chrome',
].find(p => p && existsSync(p))
if (!chrome) throw new Error('og-image: no Chromium found; set CHROME')

const profile = mkdtempSync(path.join(tmpdir(), 'og-image-'))
const before = existsSync(png) ? statSync(png).mtimeMs : 0
const browser = spawn(chrome, [
  '--headless=new',
  `--user-data-dir=${profile}`,
  // The SVG loads its fonts from ../public/fonts over file://.
  '--allow-file-access-from-files',
  '--hide-scrollbars',
  '--force-device-scale-factor=1',
  '--window-size=1200,630',
  `--screenshot=${png}`,
  pathToFileURL(svg).href,
], { stdio: 'ignore' })

// Some Chromium builds keep running after the screenshot is written, so wait
// for the file rather than for the process.
const deadline = Date.now() + 60_000
while (Date.now() < deadline) {
  await new Promise(r => setTimeout(r, 500))
  if (existsSync(png) && statSync(png).mtimeMs > before && statSync(png).size > 0) break
}
await new Promise(r => setTimeout(r, 500))
browser.kill()
rmSync(profile, { recursive: true, force: true })

const out = readFileSync(png)
if (out.readUInt32BE(16) !== 1200 || out.readUInt32BE(20) !== 630 || statSync(png).mtimeMs <= before)
  throw new Error('og-image: no 1200x630 picture was written')
console.log(`og-image: ${path.relative(process.cwd(), png)} (1200x630, ${out.length} bytes) from ${path.basename(chrome)}`)
