// Deep links into the Function Explorer.
//
// A function is addressed by its canonical id (`neuro-image-generate`), the
// key the spec file (`specs/functions/<id>.t27`), the functions manifest and
// the bot's registry share. Nothing here reads the catalog: a bad id is a
// thrown error, never a silently different function.

import type { FunctionSpecCatalog, FunctionSpecEntry } from './agentSpecs'

/** kebab-case, lower-case ASCII, no slash, no dot -- the same rule the spec file names obey. */
const FUNCTION_ID = /^[a-z0-9]+(?:-[a-z0-9]+)*$/

export function validFunctionId(id: string): boolean {
  return FUNCTION_ID.test(id)
}

export function functionExplorerHash(id: string, options: { embedded?: boolean } = {}): string {
  if (!validFunctionId(id)) throw new Error('Invalid function id')
  const params = new URLSearchParams({ function: id })
  if (options.embedded) params.set('embed', '1')
  return `#/functions?${params}`
}

export function canonicalFunctionUrl(id: string): string {
  return `https://t27.ai/${functionExplorerHash(id)}`
}

/** An explicit broken link must never silently show a different function. */
export function resolveFunction(catalog: FunctionSpecCatalog, wanted: string | null): FunctionSpecEntry {
  if (wanted === null) {
    const first = catalog.functions[0]
    if (!first) throw new Error('The function catalog is empty')
    return first
  }
  if (!validFunctionId(wanted)) throw new Error('Invalid function id')
  const hit = catalog.functions.find((f) => f.id === wanted)
  if (!hit) throw new Error(`No function ${wanted} in the catalog`)
  return hit
}

/** The source line of the registration on GitHub: SERVICE is `file:line` in REPO, on the commit the manifest names. */
export function functionSourceUrl(repo: string, service: string, commit: string | null): string | null {
  const m = /^(.+?):(\d+)$/.exec(service)
  if (!m) return null
  const owner = repo.includes('/') ? repo : `gHashTag/${repo}`
  return `https://github.com/${owner}/blob/${commit ?? 'main'}/${m[1]}#L${m[2]}`
}
