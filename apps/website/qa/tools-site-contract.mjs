// Can the site open every card the tools catalog carries?
//
// Catalog schema 2 (#991) added the witness `registry-export` and ids qualified by
// repository (`gHashTag/trinity:tri/bench`). The site knew neither: WITNESS_LABEL
// had no entry for the witness and TOOL_ID refused the id. The Tool Explorer opens
// the first card when no `tool=` is given, which is exactly the Queen's Tools tab
// (#/tools?embed=1), and that first card was a qualified registry-export one — so
// the tab threw on every boot and stayed blank, and the same iframe carried the
// blank page into the Skills, Crons, Agents, Functions and Project tabs.
//
// Nothing noticed for a day because every check that could have was elsewhere:
// tools-spec-contract.mjs asserts the generator's side and stops earlier on an
// unrelated failure, and explorer-viewport-contract.mjs deep-linked a short id.
// This file asks only the site's question, from the generator's own vocabulary:
// every witness the generator may emit has a label in both languages, and every id
// it emitted passes the site's address parser and resolves back to its own card.
//
//   node --experimental-strip-types qa/tools-site-contract.mjs

import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { TOOLS_OUT, TOOL_WITNESSES } from '../scripts/agents-from-specs.mjs'
import { WITNESS_LABEL } from '../src/lib/agentSpecs.ts'
import { normalizeToolId, resolveTool, toolExplorerHash } from '../src/lib/toolsCatalog.ts'

const catalog = JSON.parse(readFileSync(TOOLS_OUT, 'utf8'))
assert.ok(catalog.tools.length > 0, 'the tools catalog is empty — nothing here would be checked')

for (const w of TOOL_WITNESSES) {
  assert.ok(WITNESS_LABEL[w]?.en && WITNESS_LABEL[w]?.ru, `witness ${w}: the generator may emit it and the site has no label for it`)
}

let qualified = 0
for (const t of catalog.tools) {
  assert.ok(TOOL_WITNESSES.includes(t.witness), `${t.id}: witness ${t.witness} is outside the generator's vocabulary`)
  assert.equal(normalizeToolId(t.id), t.id, `${t.id}: the site's address parser refuses a catalog id`)
  assert.equal(resolveTool(catalog, t.id), t, `${t.id}: its own address does not resolve back to it`)
  assert.ok(toolExplorerHash(t.id).includes(`tool=${encodeURIComponent(t.id)}`), `${t.id}: the hash does not carry the id`)
  if (t.id.includes(':')) qualified++
}

// The default card — what the Queen's Tools tab shows — is the first one.
assert.equal(resolveTool(catalog, null), catalog.tools[0])
// A malformed or unknown address is still a thrown error, never a different tool.
assert.throws(() => normalizeToolId('tri/'), /Invalid tool id/)
assert.throws(() => normalizeToolId('gHashTag/trinity:other/bench'), /Invalid tool id/)
assert.throws(() => resolveTool(catalog, 'tri/no-such-command-anywhere'), /No tool with id/)

console.log(
  `tools-site-contract: ${catalog.tools.length} cards open (${qualified} qualified), ` +
  `${TOOL_WITNESSES.length} witnesses labelled, default card ${catalog.tools[0].id}`,
)
