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

/**
 * Routes that already had off-screen controls when this check was added.
 *
 * Named, not counted, and deliberately not a number: a count lets a new
 * offender in whenever an old one is fixed. These two are real -- /queen hides
 * an ALERTS button at left 850px and a MENU at 417px, /tree an ALERTS button at
 * 912px, all on a 375px screen, all clipped by an ancestor's overflow:hidden so
 * nothing scrolls and nothing complains. They are separate pages with their own
 * layouts; fixing them is not this change. The gate forbids NEW ones.
 */
export const KNOWN_UNREACHABLE = new Set(['queen', 'tree'])

/** A control outside the viewport is a function the reader cannot reach. */
export function hasUnreachableControl(measurement) {
  return Array.isArray(measurement.unreachable) && measurement.unreachable.length > 0
}

export function selfTest() {
  if (!isOverflowing({ overflow: 40 })) throw new Error('self-test: a 40px overflow must be reported')
  if (isOverflowing({ overflow: 0 })) throw new Error('self-test: a fitting page must not be reported')
  if (isOverflowing({ overflow: TOLERANCE_PX })) throw new Error('self-test: sub-pixel slop must be tolerated')
  if (!isOverflowing({ overflow: TOLERANCE_PX + 1 })) throw new Error('self-test: just past tolerance must be reported')
  if (!hasUnreachableControl({ unreachable: [{ tag: 'button' }] })) throw new Error('self-test: an off-screen control must be reported')
  if (hasUnreachableControl({ unreachable: [] })) throw new Error('self-test: a page with every control on screen must pass')
  if (hasUnreachableControl({})) throw new Error('self-test: a measurement without the field must not fail')
  if (!ROUTES.length) throw new Error('self-test: no routes to audit')
  console.log(`mobile self-test: PASS (${ROUTES.length} routes, tolerance ${TOLERANCE_PX}px)`)
}

// Runs inside the page. Reports the overflow and, when there is one, the widest
// element that exceeds the viewport -- the thing actually pushing the page out.
// Two questions, because one of them has a blind spot.
//
// documentElement.scrollWidth is what a reader feels -- it is the sideways
// scroll. But an ancestor with overflow:hidden CLAMPS it, so a control pushed
// off the edge inside such a container is invisible to it. That is not
// hypothetical: adding the language switcher to the Spec Explorer header put
// its right edge at 384px on a 375px screen, the header clipped it, and this
// gate stayed green while a button was unreachable.
//
// So also ask, per element, whether anything INTERACTIVE lies outside the
// viewport. A clipped paragraph is a cosmetic loss; a clipped button is a
// function the reader cannot reach.
const MEASURE = `(() => {
  const d = document.documentElement;
  const client = d.clientWidth;
  const overflow = d.scrollWidth - client;
  const unreachable = [];
  for (const el of document.querySelectorAll('button, a, input, select, textarea, [role="button"]')) {
    const r = el.getBoundingClientRect();
    if (r.width === 0 && r.height === 0) continue;      // not rendered
    if (getComputedStyle(el).visibility === 'hidden') continue;
    if (r.right > client + 1 || r.left < -1) {
      unreachable.push({
        tag: el.tagName.toLowerCase(),
        txt: (el.textContent || '').trim().slice(0, 24),
        left: Math.round(r.left),
        right: Math.round(r.right),
      });
    }
  }
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
  return { client, scrollWidth: d.scrollWidth, overflow, widest, unreachable: unreachable.slice(0, 5) };
})()`

async function main() {
  if (process.argv.includes('--selftest')) { selfTest(); return }

  const baseUrl = process.env.AUDIT_BASE_URL || 'http://127.0.0.1:4173/index.html'
  const measurements = await forEachRoute(baseUrl, MEASURE, { windowSize: VIEWPORT })

  const offenders = []
  for (const route of ROUTES) {
    const m = measurements[route]
    if (!m) continue
    const unreachableIsNew = hasUnreachableControl(m) && !KNOWN_UNREACHABLE.has(route)
    if (isOverflowing(m) || unreachableIsNew) offenders.push({ route, ...m, unreachableIsNew })
  }

  const baselineStillBad = [...KNOWN_UNREACHABLE].filter((r) => hasUnreachableControl(measurements[r] || {}))
  const baselineFixed = [...KNOWN_UNREACHABLE].filter((r) => measurements[r] && !hasUnreachableControl(measurements[r]))
  console.log(`mobile audit: ${VIEWPORT.width}x${VIEWPORT.height}, ${ROUTES.length} routes`)
  if (baselineStillBad.length) {
    console.log(`  baseline (not failed, still to fix): ${baselineStillBad.map((r) => '/' + r).join(', ')}`)
  }
  if (baselineFixed.length) {
    console.log(`  baseline route(s) now clean -- remove from KNOWN_UNREACHABLE: ${baselineFixed.map((r) => '/' + r).join(', ')}`)
  }
  if (!offenders.length) {
    console.log('mobile audit: PASS — no route scrolls sideways')
    return
  }

  console.error(`mobile audit: ${offenders.length} route(s) fail at ${VIEWPORT.width}px\n`)
  for (const o of offenders) {
    const w = o.widest
    if (isOverflowing(o)) {
      console.error(`  /${o.route || '(home)'} — scrolls sideways, over by ${o.overflow}px` +
        (w ? `; widest: <${w.tag}${w.cls ? ` class="${w.cls}"` : ''}> ${w.width}px, right edge ${w.right}px` : ''))
    }
    for (const u of (o.unreachableIsNew ? o.unreachable : [])) {
      console.error(`  /${o.route || '(home)'} — <${u.tag}> "${u.txt}" is off-screen: ` +
        `left ${u.left}px, right ${u.right}px, viewport ${o.client}px`)
    }
  }
  process.exitCode = 1
}

main().catch((e) => {
  console.error(`mobile audit not run: ${e.message}`)
  process.exitCode = 1
})
