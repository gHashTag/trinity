// The cache tag for the vendored compiler wasm: the first 16 hex of its SHA-256.
//
// One module because there are two readers and they must never disagree.
// `vite.config.ts` substitutes the tag into the bundle; `qa/spec-catalog-
// contract.mjs` supplies it to the same driver running under node. Computed
// twice from a copied expression, a drift between them would be invisible
// exactly where it matters -- the gate would assert the URL it had itself
// invented, and the build would ship a different one.
//
// Why a tag at all: nginx at app.t27.ai answers every .wasm under /queen/ with
// `expires 1y; Cache-Control: public, immutable`. `immutable` tells a browser
// the bytes behind a URL will never change, so it does not revalidate and does
// not send If-None-Match for a year. On a path with no hash that promise is
// false. Shipping the seventh backend proved it: the new bundle drew a
// TypeScript tab and asked the cached six-backend compiler to fill it, which
// answered "This backend produced no output". Same URL, two compilers --
// 695 132 bytes and six targets from cache, 712 420 bytes and seven off the
// wire. With the hash in the query the header becomes true, because different
// bytes are a different URL and the stale entry is simply never asked for.
//
// TypeScript rather than .mjs, though nothing here needs a type annotation:
// `vite.config.ts` is type-checked by `npm run typecheck:ratchet`, and importing
// an untyped .mjs from it is an implicit `any` -- TS7016, which the ratchet read
// as a file that had gained an error. Both readers take it as it is: vite loads
// its config through esbuild, and every qa gate already runs under
// `node --experimental-strip-types` and imports .ts by its real extension.
//
// Read from the file the build is about to copy, which is the only source that
// cannot be stale. `public/t27/manifest.json` also describes this artifact, but
// it is written by `sync-t27-specs.mjs`, which nothing in `npm run build`
// invokes -- a tag taken from there would go stale precisely when the wasm
// changed without a sync, re-freezing the cache under a key that had already
// been handed out. That is the one case this exists for.

import { createHash } from 'node:crypto'
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

/** The wasm the site serves, resolved from this file rather than from cwd. */
export const T27_WASM_PATH = fileURLToPath(
  new URL('../public/t27/t27_compiler.wasm', import.meta.url),
)

/**
 * The tag for the wasm currently on disk.
 *
 * Throws when the file is absent rather than returning a placeholder: a silent
 * fall-through is how the vendored artifact drifted away from the compiler for
 * months in the first place (see the header of src/lib/t27Compiler.ts), and an
 * untagged URL is the exact bug this module exists to prevent.
 */
export function t27WasmTag(): string {
  let bytes
  try {
    bytes = readFileSync(T27_WASM_PATH)
  } catch (error) {
    const why = error instanceof Error ? error.message : String(error)
    throw new Error(`t27-wasm-tag: cannot read ${T27_WASM_PATH}: ${why}`)
  }
  return createHash('sha256').update(bytes).digest('hex').slice(0, 16)
}
