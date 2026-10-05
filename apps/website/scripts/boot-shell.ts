// The first screen, written into index.html at build time.
//
// The page is a client-rendered SPA, so #root shipped empty: nothing was on
// screen until 524 kB of JavaScript had downloaded, parsed and mounted, and
// anything that does not run JS -- every preview bot, and crawlers on their
// first pass -- saw a document with no heading and no prose at all. This shell
// is what they see instead. React clears it on its first render.
//
// One module, two readers: vite.config.ts writes the shell into index.html, and
// qa/boot-shell-contract.mjs holds it to the rules below. Until 2026-10-04 the
// shell was read from messages/en.json `hero`, the GFTernary/TNF hero the site
// no longer opens on -- so for a crawler the home page said one thing and for
// a reader another, and it linked to two pages out of eleven.
//
// The words are lib/motto's, the same import GameHero renders: the wordmark,
// the caption under it, and the headline. They cannot drift from the first
// screen because they are not a copy of it. The mark is the bare triangle, as
// GameHero draws it (TrinityLogo withLabel={false}): the labelled logo said
// TRINITY right above a wordmark saying it again. It is decorative -- alt="" --
// because the wordmark under it is the name, and a screen reader read it twice.

import { COURSE } from '../src/lib/course.generated.ts'
import { MOTTO, SITE_NAME } from '../src/lib/motto.ts'

export const escapeHtml = (s: unknown) =>
  String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')

// Where the static pages live. Absolute, not relative: the same build is also
// served under https://app.t27.ai/game/, where a relative `gft/` asks
// app.t27.ai/game/gft/ -- not a page (qa/subpath-safe-urls-contract.mjs has
// the measurements). The #/ hash routes the app uses are no good here either:
// a crawler drops everything after `#`, so to it they are all the home page.
export const APEX = 'https://t27.ai/'

// The sections t27.ai serves as real HTML, readable with JavaScript switched
// off. These are the links a crawler's first pass can follow from the home
// page; before this list it could follow two. Whether each one resolves is the
// apex's to check, because the apex is what builds them (gHashTag/
// ghashtag.github.io build-landing.py and build-blog.py) -- this file only
// names them.
export const STATIC_PAGES = [
  { path: 'blog/', label: 'Blog: measured results' },
  { path: 'proof/', label: 'Every number here was measured' },
  { path: 'verification/', label: 'RTL verified on an FPGA' },
  { path: 'ip/', label: 'Arithmetic cores' },
  { path: 'gft/', label: 'GF-T, a ternary-native float' },
  { path: 'cases/', label: "Runs on other people's RTL" },
  { path: 'status/', label: 'What has been checked, and when' },
  // The free course: static lesson pages written by scripts/course-pages.mjs.
  // Before this link they were reachable from nowhere but learn/sitemap.xml.
  { path: 'learn/', label: COURSE.say.en.TITLE },
  { path: 'course/', label: 'Train a neural network on an FPGA' },
  { path: 'resources/', label: 'Papers, datasets and patches' },
  { path: 'about/', label: 'About' },
] as const

// The Russian entry point. Its own entry because it carries its own language:
// hreflang tells a crawler what is behind the link, lang tells a screen reader
// how to say the label.
export const RU_PAGE = { path: 'ru/', label: MOTTO.ru.headline } as const

export function bootShell(): string {
  const m = MOTTO.en
  const link = (p: { path: string; label: string }) =>
    `<a href="${APEX}${p.path}">${escapeHtml(p.label)}</a>`
  return `<div id="boot">
      <img src="favicon.svg" alt="" width="512" height="512" />
      <p class="mark">${escapeHtml(SITE_NAME)}</p>
      <p class="cap">${escapeHtml(m.caption)}</p>
      <h1>${escapeHtml(`${m.headline}: ${m.clause}`)}</h1>
      <nav aria-label="Pages">
        ${STATIC_PAGES.map(link).join('\n        ')}
        <a href="${APEX}${RU_PAGE.path}" hreflang="ru" lang="ru">${escapeHtml(RU_PAGE.label)}</a>
      </nav>
    </div><!-- /boot -->`
}
