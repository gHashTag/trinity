// Deep links into the Tool Explorer.
//
// A tool is addressed by its catalog id: `tri/<command>` for a clap variant of
// the t27 `tri` CLI, `mcp/<server>` for an MCP server. The id is the file name
// under specs/tools/{tri,mcp}/ and the key the generated catalog uses, so a
// chip on an agent card links without a lookup. Nothing here reads the
// catalog: a bad id is a thrown error, never a silently different tool.

import type { ToolSpecCatalog, ToolSpecEntry } from './agentSpecs'

const TOOL_ID = /^(tri|mcp)\/[a-z0-9][a-z0-9-]*$/

export function normalizeToolId(raw: string): string {
  const s = raw.trim()
  if (!TOOL_ID.test(s)) throw new Error('Invalid tool id')
  return s
}

export function toolExplorerHash(id: string, options: { embedded?: boolean } = {}): string {
  const params = new URLSearchParams({ tool: normalizeToolId(id) })
  if (options.embedded) params.set('embed', '1')
  return `#/tools?${params}`
}

export function canonicalToolUrl(id: string): string {
  return `https://t27.ai/${toolExplorerHash(id)}`
}

/** An explicit broken link must never silently show a different tool. */
export function resolveTool(catalog: ToolSpecCatalog, wanted: string | null): ToolSpecEntry {
  if (wanted === null) {
    const first = catalog.tools[0]
    if (!first) throw new Error('The tool catalog is empty')
    return first
  }
  const id = normalizeToolId(wanted)
  const hit = catalog.tools.find((t) => t.id === id)
  if (!hit) throw new Error(`No tool with id ${id} in the catalog`)
  return hit
}
