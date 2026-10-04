/**
 * THE SIGNED-OUT GUIDE ON BROWSER: which spec, if any, it may name.
 *
 * Signed out, BROWSER was one sentence and one button (measured with
 * `tri harness`, 2026-10-04). The guide in QueenBrowser.tsx says what the tab
 * does once signed in, and -- when the address names a spec, as
 * app.t27.ai/game/browser?spec=specs%2Fdemos%2Fhello_world.t27 does -- names it
 * and links to SPECS, which needs no sign-in. No model call, no backend.
 *
 * `spec=` is text from the address bar, and the guide prints it to whoever
 * opens the link. The Explorer's own rule (specCatalog.specExplorerHash) refuses
 * `..`, `%`, `:` and control characters but accepts spaces, so
 * `spec=Paste your token here.t27` passes it and would be printed on our page
 * as if we had written it. The guide therefore asks two things, in this order:
 *
 *   - PLAIN: letters, digits, `_`, `.`, `-` and `/` only, at most
 *     GUIDE_SPEC_MAX characters -- what is safe to print to a stranger;
 *   - the Explorer accepts it -- the same rule SPECS opens a card with,
 *     imported, not restated here.
 *
 * Measured, 2026-10-04: all 1776 paths in public/t27/manifest.json are plain
 * and accepted (qa/queen-browser-guide-contract.mjs reads the file, so a
 * catalog path the guide would hide fails the contract).
 */

import { specExplorerHash } from './specCatalog.ts'

/** The longest catalog path on 2026-10-04 is 96 characters. */
export const GUIDE_SPEC_MAX = 200

const PLAIN = /^[A-Za-z0-9_./-]+$/

/** The spec the guide may name, or null: absent, not plain, or refused by the Explorer. */
export function guideSpecOf(raw: string | null | undefined): string | null {
  if (!raw || raw.length > GUIDE_SPEC_MAX || !PLAIN.test(raw)) return null
  try {
    specExplorerHash(raw)
  } catch {
    return null
  }
  return raw
}

/**
 * The address of that spec on SPECS, for a new tab or a copied link. A press
 * goes through the Queen's own setView instead (Queen.tsx onReadSpec), which
 * keeps the rest of the address the way every tab switch does.
 */
export function guideSpecHref(spec: string): string {
  return `#/queen?${new URLSearchParams({ tab: 'specs', spec })}`
}
