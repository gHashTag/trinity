// Deep links into the Provider Explorer.
//
// A provider is addressed by its ID, the path of its spec under specs/providers
// without .t27 (`gonka/minimax-m2-7`, `trinet/fpga-xc7a200t`), as
// specs/providers/catalog.t27 ID_RULE states it. Nothing here reads the catalog:
// a bad id is a thrown error, never a silently different provider.

import type { ProviderSpecCatalog, ProviderSpecEntry } from './agentSpecs'

/** <network>/<slug>: one of the two networks catalog.t27 NETWORKS names, then lower-case kebab. */
const PROVIDER_ID = /^(gonka|trinet)\/[a-z0-9]+(?:-[a-z0-9]+)*$/

export function validProviderId(id: string): boolean {
  return PROVIDER_ID.test(id)
}

export function providerExplorerHash(id: string, options: { embedded?: boolean } = {}): string {
  if (!validProviderId(id)) throw new Error('Invalid provider id')
  const params = new URLSearchParams({ provider: id })
  if (options.embedded) params.set('embed', '1')
  return `#/providers?${params}`
}

export function canonicalProviderUrl(id: string): string {
  return `https://t27.ai/${providerExplorerHash(id)}`
}

/** An explicit broken link must never silently show a different provider. */
export function resolveProvider(catalog: ProviderSpecCatalog, wanted: string | null): ProviderSpecEntry {
  if (wanted === null) {
    const first = catalog.providers[0]
    if (!first) throw new Error('The provider catalog is empty')
    return first
  }
  if (!validProviderId(wanted)) throw new Error('Invalid provider id')
  const hit = catalog.providers.find((p) => p.id === wanted)
  if (!hit) throw new Error(`No provider ${wanted} in the catalog`)
  return hit
}
