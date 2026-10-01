/**
 * The TECH TREE draws the evolution of the .t27 language, and every number in
 * it has to come out of the corpus index this site already ships. This gate
 * executes the derivation rather than reading it: it hands deriveT27Evolution
 * the real public/t27/manifest.json, then hands it a mutated copy, and requires
 * the drawing to move. A tree whose numbers do not move when the corpus moves
 * is a tree of literals, which is the one thing the tab must never be.
 *
 * It also holds three things the tree got wrong once and must not get wrong
 * again: a node locked underneath its own evidence that it ran, a label in the
 * wrong script for the page it is drawn on, and a silicon claim this index
 * cannot support.
 */

import { existsSync, readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { build } from 'esbuild'

const root = fileURLToPath(new URL('..', import.meta.url))
const modulePath = `${root}/src/lib/t27Evolution.ts`
const manifestPath = `${root}/public/t27/manifest.json`
const queenPath = `${root}/src/pages/Queen.tsx`
const errors = []

const fail = (message) => errors.push(message)
const CYRILLIC = /[А-Яа-яЁё]/

if (!existsSync(modulePath)) fail('src/lib/t27Evolution.ts is missing')
if (!existsSync(manifestPath)) {
  fail('public/t27/manifest.json is missing -- the tree has nothing to read')
}

if (errors.length === 0) {
  const bundled = await build({
    entryPoints: [modulePath],
    bundle: true,
    format: 'esm',
    platform: 'node',
    write: false,
    logLevel: 'silent',
  })
  const source = bundled.outputFiles[0].text
  const { deriveT27Evolution } = await import(
    `data:text/javascript;base64,${Buffer.from(source).toString('base64')}`
  )

  // A missing or unrecognisable index must produce nothing, so the tab can say
  // it has nothing rather than draw a confident empty tree.
  for (const [name, input] of [
    ['null', null],
    ['a string', 'manifest'],
    ['an array', []],
    ['an object with no specs', { specCount: 1407 }],
    ['an object with empty specs', { specs: [] }],
    ['specs that are not records', { specs: [1, 'two', null] }],
  ]) {
    if (deriveT27Evolution(input, 'en') !== null) {
      fail(`A manifest that is ${name} must derive no tree at all`)
    }
  }

  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'))
  const graph = deriveT27Evolution(manifest, 'en')
  if (!graph) {
    fail('The shipped manifest derived no tree')
  } else {
    const byId = new Map(graph.nodes.map((node) => [node.id, node]))

    if (graph.nodes.length < 10) {
      fail(`The tree is ${graph.nodes.length} nodes; the corpus supports more`)
    }
    if (!graph.source.specs || graph.source.specs < 1) {
      fail('The tree must carry the spec count it was read from')
    }
    if (!/^[0-9a-f]{7,40}$/.test(graph.source.commit)) {
      fail(`Corpus commit is not a commit: ${graph.source.commit}`)
    }

    for (const node of graph.nodes) {
      if (!node.id || !node.label || !node.layer) {
        fail(`Node ${node.id || '(no id)'} is missing id, label or layer`)
      }
      if (!node.evidence || node.evidence.length < 12) {
        fail(`Node ${node.id} is drawn without evidence`)
      }
      if (!graph.layers.includes(node.layer)) {
        fail(`Node ${node.id} sits in layer ${node.layer}, which is not drawn`)
      }
      for (const id of node.prerequisites) {
        if (!byId.has(id)) fail(`Node ${node.id} requires ${id}, which does not exist`)
        if (id === node.id) fail(`Node ${node.id} requires itself`)
      }
      for (const id of node.unlocks) {
        if (!byId.has(id)) fail(`Node ${node.id} unlocks ${id}, which does not exist`)
      }
      // The defect this line exists for: gen-rust drawn as locked while its own
      // evidence said 1 405 specs and 3.6 MB had come out of it, because the
      // type check above it carries warnings. Locked means a prerequisite is
      // unmeasured, never merely imperfect.
      if (node.state === 'locked' && !node.blockedBy) {
        fail(`Node ${node.id} is locked by nothing in particular`)
      }
      if (node.blockedBy && byId.get(node.blockedBy)?.state === 'researched') {
        fail(`Node ${node.id} is blocked by ${node.blockedBy}, which is researched`)
      }
    }

    for (const edge of graph.edges) {
      if (!byId.has(edge.from)) fail(`Edge from ${edge.from}, which does not exist`)
      if (!byId.has(edge.to)) fail(`Edge to ${edge.to}, which does not exist`)
      if (!byId.get(edge.to)?.prerequisites.includes(edge.from)) {
        fail(`Edge ${edge.from} -> ${edge.to} contradicts that node's prerequisites`)
      }
    }
    for (const layer of graph.layers) {
      if (!graph.nodes.some((node) => node.layer === layer)) {
        fail(`Layer ${layer} is drawn with no nodes in it`)
      }
    }

    const { summary } = graph
    const counted =
      summary.researched + summary.researching + summary.available + summary.locked
    if (summary.total !== graph.nodes.length || counted !== summary.total) {
      fail(`Summary counts ${counted} of ${summary.total} for ${graph.nodes.length} nodes`)
    }
    const expected = Math.round((summary.researched / summary.total) * 100)
    if (summary.percentage !== expected) {
      fail(`Summary percentage is ${summary.percentage}, arithmetic says ${expected}`)
    }

    // Hardware honesty. This index knows how many specs describe an FPGA; it
    // cannot know what a board was programmed with, and the register that does
    // belongs to another agent.
    const silicon = byId.get('silicon')
    if (!silicon) {
      fail('The tree has no silicon node')
    } else {
      if (silicon.state === 'researched') {
        fail('The silicon node claims a result this corpus index cannot measure')
      }
      if (!/HARDWARE_SSOT\.md/.test(silicon.note ?? '')) {
        fail('The silicon node must point at the hardware register rather than keep one')
      }
    }

    // Language. publicResearchText replaces any label or detail whose script
    // does not match the page, so a graph that answers in one language while
    // the page renders the other loses every label it drew.
    const ru = deriveT27Evolution(manifest, 'ru')
    if (!ru) {
      fail('The shipped manifest derived no Russian tree')
    } else {
      for (const node of graph.nodes) {
        if (CYRILLIC.test(node.label)) fail(`English node ${node.id} has a Cyrillic label`)
        if (CYRILLIC.test(node.evidence)) fail(`English node ${node.id} has Cyrillic evidence`)
      }
      for (const node of ru.nodes) {
        if (!CYRILLIC.test(node.label)) {
          fail(`Russian node ${node.id} has no Cyrillic in its label: ${node.label}`)
        }
        if (!CYRILLIC.test(node.evidence)) {
          fail(`Russian node ${node.id} has no Cyrillic in its evidence`)
        }
      }
      if (ru.nodes.length !== graph.nodes.length) {
        fail('The two languages derive different trees')
      }
    }

    // The point of the whole file: move the corpus, and the drawing moves.
    const mutated = structuredClone(manifest)
    mutated.specs = mutated.specs.slice(0, Math.floor(mutated.specs.length / 3))
    mutated.specCount = mutated.specs.length
    if (mutated.totals && typeof mutated.totals === 'object') {
      mutated.totals.tcAffected = 0
      mutated.totals.lossAffected = 0
    }
    const moved = deriveT27Evolution(mutated, 'en')
    if (!moved) {
      fail('A smaller corpus derived no tree')
    } else {
      if (moved.source.specs === graph.source.specs) {
        fail('The spec count did not follow the manifest')
      }
      const unchanged = moved.nodes.filter((node) => {
        const original = byId.get(node.id)
        return original && original.evidence === node.evidence
      })
      if (unchanged.length > 2) {
        fail(
          `${unchanged.length} nodes kept their evidence across a corpus a third the size: ` +
            unchanged.map((node) => node.id).join(', '),
        )
      }
      const typecheck = moved.nodes.find((node) => node.id === 'typecheck')
      if (typecheck && typecheck.state !== 'researched') {
        fail('A corpus with no type errors must draw the type check as researched')
      }
    }

    // No corpus literal may be written into the derivation. The counts above
    // are the ones a copy-paste would most plausibly leave behind.
    const literal = readFileSync(modulePath, 'utf8')
    for (const value of [graph.source.specs, graph.source.commit]) {
      if (new RegExp(`\\b${String(value)}\\b`).test(literal)) {
        fail(`The derivation hard-codes ${value} instead of reading it`)
      }
    }

    // Every layer the tree draws needs a design and a caption on the page, or
    // it arrives as a white diamond labelled with its own identifier.
    const queen = readFileSync(queenPath, 'utf8')
    const block = (name) => {
      const start = queen.indexOf(`const ${name}`)
      return start < 0 ? '' : queen.slice(start, queen.indexOf('\n};', start))
    }
    const design = block('LAYER_DESIGN')
    const caption = block('LAYER_CAPTION')
    for (const layer of graph.layers) {
      if (!new RegExp(`^\\s*${layer}:`, 'm').test(design)) {
        fail(`Layer ${layer} has no entry in LAYER_DESIGN and draws a white diamond`)
      }
      if (!new RegExp(`^\\s*${layer}:`, 'm').test(caption)) {
        fail(`Layer ${layer} has no entry in LAYER_CAPTION and prints its own id`)
      }
    }
    if (!/deriveT27Evolution\(manifest, lang\)/.test(queen)) {
      fail('Queen must derive the tree in the language the page is rendered in')
    }
  }

  // The target list is written twice and nothing used to join the two halves.
  //
  // `TARGET_IDS` in src/lib/t27Compiler.ts is what the bundle imports; scripts/
  // t27-corpus.mjs cannot import it -- node runs that file directly -- so it
  // keeps a parallel `TARGET_LABEL`. The comment above that literal conceded the
  // gap in as many words: the two "can disagree about a name". Adding gen-ts
  // walked straight through it, because a seventh id with no label is not a
  // crash. It is a backend that emits, is counted, and renders as a blank tab.
  //
  // So bind both to the thing that cannot be typed by hand: the manifest, whose
  // backend names are whatever the vendored compiler actually emitted over the
  // corpus. Three lists, one measured source, and the next backend is added in
  // one place or the gate says where the other one is.
  const { TARGET_IDS } = await import(
    `data:text/javascript;base64,${Buffer.from(
      (await build({
        entryPoints: [`${root}/src/lib/t27Compiler.ts`],
        bundle: true, format: 'esm', platform: 'node', write: false, logLevel: 'silent',
      })).outputFiles[0].text,
    ).toString('base64')}`
  )
  const { TARGET_LABEL } = await import(`${root}/scripts/t27-corpus.mjs`)
  const emitted = [...new Set(manifest.specs.flatMap((s) => Object.keys(s.outBytes ?? {})))].sort()

  const ids = [...TARGET_IDS].sort()
  if (ids.join() !== emitted.join()) {
    fail(`TARGET_IDS is [${ids}], the corpus index emits [${emitted}]`)
  }
  const labelled = Object.keys(TARGET_LABEL).sort()
  if (labelled.join() !== emitted.join()) {
    fail(`TARGET_LABEL covers [${labelled}], the corpus index emits [${emitted}]`)
  }
  for (const [id, label] of Object.entries(TARGET_LABEL)) {
    if (typeof label !== 'string' || !label.trim()) fail(`TARGET_LABEL.${id} has no name to draw`)
  }
}

if (errors.length) {
  console.error('T27 evolution contract: FAIL')
  for (const error of errors) console.error(`  - ${error}`)
  process.exit(1)
}
console.log('T27 evolution contract: PASS (tree derived from the shipped corpus index)')
