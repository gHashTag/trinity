#!/usr/bin/env node
//
// Does every route fit on a phone?
//
// One objective question, asked of all 28 routes at 375x812: does the page
// scroll SIDEWAYS. A horizontal scrollbar on a phone is not a matter of taste —
// it means content is off-screen and the reader has to drag the page to find
// it. It is measurable without judging a design, which is why this gate checks
// that and not "does it look right".
//
// /specs was fixed by hand after being caught this way: at 375px its desktop
// two-pane layout left ~150px for the detail, wrapped every word of the
// description onto its own line, and overflowed anyway. Nothing would have told
// us about the other 27 routes.
//
// The gate also names the widest offending element, because "this page
// overflows by 42px" sends you looking and "the .queen-grid is 417px wide"
// sends you to the line.
//
// Usage:
//   node qa/mobile_audit.mjs
//   node qa/mobile_audit.mjs --selftest

import { forEachRoute, ROUTES } from './browser-audit.mjs'

export const VIEWPORT = { width: 375, height: 812 }

// A few pixels of slop: sub-pixel layout rounding can make scrollWidth exceed
// clientWidth by a fraction on a page that is visually fine. Two pixels is
// below what a reader can drag to and well under a real overflow.
export const TOLERANCE_PX = 2

export function isOverflowing(measurement, tolerance = TOLERANCE_PX) {
  return measurement.overflow > tolerance
}

export function selfTest() {
  if (!isOverflowing({ overflow: 40 })) throw new Error('self-test: a 40px overflow must be reported')
  if (isOverflowing({ overflow: 0 })) throw new Error('self-test: a fitting page must not be reported')
  if (isOverflowing({ overflow: TOLERANCE_PX })) throw new Error('self-test: sub-pixel slop must be tolerated')
  if (!isOverflowing({ overflow: TOLERANCE_PX + 1 })) throw new Error('self-test: just past tolerance must be reported')
  if (!ROUTES.length) throw new Error('self-test: no routes to audit')
  console.log(`mobile self-test: PASS (${ROUTES.length} routes, tolerance ${TOLERANCE_PX}px)`)
}

// Runs inside the page. Reports the overflow and, when there is one, the widest
// element that exceeds the viewport -- the thing actually pushing the page out.
const MEASURE = `(() => {
  const d = document.documentElement;
  const client = d.clientWidth;
  const overflow = d.scrollWidth - client;
  let widest = null;
  if (overflow > 0) {
    let best = 0;
    for (const el of document.querySelectorAll('*')) {
      const r = el.getBoundingClientRect();
      const right = r.left + r.width;
      if (r.width > client + 1 || right > client + 1) {
        const score = Math.max(r.width, right);
        if (score > best) {
          best = score;
          const cls = typeof el.className === 'string' ? el.className : '';
          widest = {
            tag: el.tagName.toLowerCase(),
            cls: cls.slice(0, 40),
            width: Math.round(r.width),
            right: Math.round(right),
          };
        }
      }
    }
  }
  return { client, scrollWidth: d.scrollWidth, overflow, widest };
})()`

async function main() {
  if (process.argv.includes('--selftest')) { selfTest(); return }

  const baseUrl = process.env.AUDIT_BASE_URL || 'http://127.0.0.1:4173/index.html'
  const measurements = await forEachRoute(baseUrl, MEASURE, { windowSize: VIEWPORT })

  const offenders = []
  for (const route of ROUTES) {
    const m = measurements[route]
    if (!m) continue
    if (isOverflowing(m)) offenders.push({ route, ...m })
  }

  console.log(`mobile audit: ${VIEWPORT.width}x${VIEWPORT.height}, ${ROUTES.length} routes`)
  if (!offenders.length) {
    console.log('mobile audit: PASS — no route scrolls sideways')
    return
  }

  console.error(`mobile audit: ${offenders.length} route(s) scroll sideways at ${VIEWPORT.width}px\n`)
  for (const o of offenders) {
    const w = o.widest
    console.error(`  /${o.route || '(home)'} — overflows by ${o.overflow}px` +
      (w ? `; widest: <${o.tag || w.tag}${w.cls ? ` class="${w.cls}"` : ''}> ${w.width}px, right edge ${w.right}px` : ''))
  }
  process.exitCode = 1
}

main().catch((e) => {
  console.error(`mobile audit not run: ${e.message}`)
  process.exitCode = 1
})
