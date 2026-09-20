// Browser-side driver for the real t27 compiler, compiled to WebAssembly.
//
// The wasm module is `bootstrap/src/compiler.rs` built for
// wasm32-unknown-unknown -- the same code the CLI runs, not a reimplementation.
// See apps/website/scripts/sync-t27-specs.mjs for how the artifact gets here.
//
// That sentence was an ASPIRATION until 2026-09-21. The artifact vendored here
// had no source in any repository -- `git log -S t27_analyze` across t27 finds
// nothing -- so the sync script's build step silently fell through to the copy
// already on disk on every single run, and the binary drifted away from the
// compiler for as long as nobody could rebuild it. Measured against the CLI on
// the 1408-spec corpus, the old artifact printed an AST, a type verdict and
// five generated backends for 214 specs that `t27c parse` REFUSES, and its Zig
// output disagreed with `t27c gen` on all 40 specs sampled. The source now
// lives at `bindings/wasm-explorer/` in t27 and both numbers are zero.

import {resolveManifestSpec,specExplorerHash} from './specCatalog.ts'

export interface T27Node {
  kind: string
  line: number
  name?: string
  value?: string
  type?: string
  field?: string
  size?: string
  nodeKind?: string
  op?: string
  returnType?: string
  pub?: boolean
  mutable?: boolean
  params?: { name: string; type: string }[]
  children: T27Node[]
}

export interface T27Token {
  kind: string
  lexeme: string
  line: number
  col: number
}

export interface T27Target {
  ok: boolean
  code?: string
  bytes?: number
  error?: string
}

export interface T27Analysis {
  sourceBytes: number
  sourceLines: number
  tokenCount: number
  tokens: T27Token[]
  ast?: T27Node
  astError?: string
  nodeCount?: number
  astDepth?: number
  topLevel?: number
  /** Declarations the parser's error recovery dropped while still reporting a parse. */
  discarded: string[]
  swallowed: { what: string; line: number }[]
  lexerDiscarded: { char: string; line: number; col: number }[]
  typecheck?: { ok?: boolean; errorCount?: number; warnings?: number; errors?: string[]; fatal?: string }
  hir: { ok: boolean; text?: string; error?: string }
  targets: Record<string, T27Target>
  error?: string
}

/**
 * The backends the compiler offers, in the order the page shows them.
 *
 * One list, because there were six: the layer strip, the stage bars, the
 * metrics row, the manifest's labels, and three sentences that printed "of 5"
 * as a literal digit. Adding the JavaScript backend made every one of them
 * wrong on the same afternoon -- which is the whole argument against writing a
 * list down twice.
 *
 * `scripts/t27-corpus.mjs` cannot import this: it is run by node at sync time,
 * not bundled. It keeps its own `TARGET_LABEL` and derives its count from that
 * rather than from a digit, so the two lists can still disagree about NAMES but
 * no longer about how many there are.
 */
export const TARGET_IDS = ['zig', 'verilog', 'verilog_hir', 'c', 'rust', 'js'] as const

export type TargetId = (typeof TARGET_IDS)[number]

export type Health = 'ok' | 'warn' | 'fail'

export interface SpecEntry {
  path: string
  category: string
  name: string
  module: string | null
  lines: number
  bytes: number
  /** Leading comment block of the spec, boilerplate stripped. */
  description: string | null
  /** Precomputed at sync time by running this same compiler over the corpus. */
  health: Health
  tokens: number
  nodes: number
  depth: number
  /** Declarations + constructs + characters the compiler dropped. */
  loss: number
  tcErrors: number
  failedBackends: string[]
  outBytes: Record<string, number | null>
  /** The spec the page opens on. */
  featured?: boolean
  /** Part of the ordered course that heads the library. */
  tutorial?: boolean
  /** Reading order within the course; 0 is the overview. */
  lesson?: number
  /** Derived at sync time from path, AST node kinds and backend results. */
  tags: string[]
  /** Written-out description built from the measured compile. */
  summary: string
  /** AST node-kind histogram. */
  kinds: Record<string, number>
  repo: string
}

export interface SpecManifest {
  generatedFrom: { repo: string; commit: string; shortCommit: string; specsOrCompilerDirty: boolean }
  wasmBytes: number
  specCount: number
  totalLines: number
  categories: Record<string, number>
  health: Record<Health, number>
  backendFailures: Record<string, number>
  featured: string
  totals: { tokens: number; nodes: number; lossAffected: number; tcAffected: number }
  /** Every tag with its corpus-wide count, highest first. */
  tags: Record<string, number>
  repos: { repo: string; commit: string; specs: number }[]
  duplicatesSkipped: number
  /**
   * The copies behind that count: a file whose bytes were already vendored from
   * somewhere else, and the path that was kept instead. The losing bytes are
   * discarded at vendor time, so without this list nothing downstream could say
   * that a spec lives in more than one repository. Absent on a catalog written
   * before the list was recorded.
   */
  duplicates?: { path: string; repo: string; sameAs: string }[]
  specs: SpecEntry[]
}

interface Exports {
  memory: WebAssembly.Memory
  t27_alloc: (len: number) => number
  t27_free: (ptr: number, len: number) => void
  t27_analyze: (ptr: number, len: number) => number
  /**
   * Same analysis, told the file's name.
   *
   * `gen-js` writes the source file into the header of what it emits, so
   * without this the page shows a module claiming to come from `spec.t27` and
   * the reader cannot reproduce it at the CLI. Optional because a browser
   * holding a cached older wasm must keep working rather than throw.
   */
  t27_analyze_named?: (ptr: number, len: number, namePtr: number, nameLen: number) => number
}

let modulePromise: Promise<Exports> | null = null

/** Instantiate once and share; the module is stateless between calls. */
export function loadCompiler(): Promise<Exports> {
  if (!modulePromise) {
    modulePromise = WebAssembly.instantiateStreaming(fetch('t27/t27_compiler.wasm'), {})
      .catch(async () => {
        // instantiateStreaming needs an exact application/wasm content type,
        // which not every static host sends. Fall back to the buffer form.
        const res = await fetch('t27/t27_compiler.wasm')
        if (!res.ok) throw new Error(`could not fetch compiler wasm (${res.status})`)
        return WebAssembly.instantiate(await res.arrayBuffer(), {})
      })
      .then((r) => r.instance.exports as unknown as Exports)
  }
  return modulePromise
}

/**
 * Run one .t27 source through every pipeline layer.
 *
 * `name` is the spec's corpus path when there is one. It reaches the JavaScript
 * backend's header and nothing else, so an edited buffer with no path is not a
 * degraded case -- it just names itself.
 */
export async function analyze(source: string, name?: string): Promise<T27Analysis> {
  const wasm = await loadCompiler()
  const bytes = new TextEncoder().encode(source)
  const inPtr = wasm.t27_alloc(bytes.length)
  new Uint8Array(wasm.memory.buffer, inPtr, bytes.length).set(bytes)

  // t27_analyze takes ownership of the input allocation and returns a
  // length-prefixed blob: [u32 LE byte length][utf8 json].
  let outPtr: number
  if (name && wasm.t27_analyze_named) {
    const nb = new TextEncoder().encode(name)
    const namePtr = wasm.t27_alloc(nb.length)
    new Uint8Array(wasm.memory.buffer, namePtr, nb.length).set(nb)
    outPtr = wasm.t27_analyze_named(inPtr, bytes.length, namePtr, nb.length)
  } else {
    outPtr = wasm.t27_analyze(inPtr, bytes.length)
  }
  const len = new DataView(wasm.memory.buffer).getUint32(outPtr, true)
  const json = new TextDecoder().decode(new Uint8Array(wasm.memory.buffer, outPtr + 4, len))
  wasm.t27_free(outPtr, 4 + len)
  return JSON.parse(json) as T27Analysis
}

/**
 * Compile results, keyed by spec path.
 *
 * Re-selecting a spec, or coming back to one after wandering the library, must
 * be free -- and a cached hit deliberately skips the pending treatment
 * entirely, because there is nothing to wait for.
 */
const cache = new Map<string, {source:string;result:T27Analysis}>()
const CACHE_MAX = 24

export function cachedAnalysis(path: string,source?:string): T27Analysis | undefined {
  const hit=cache.get(path)
  return source===undefined||source===hit?.source?hit?.result:undefined
}

export async function analyzeCached(path: string, source: string): Promise<T27Analysis> {
  const hit = cache.get(path)
  if (hit?.source===source) return hit.result
  const r = await analyze(source, path)
  // Plain FIFO eviction: these are a few hundred KB each at worst and the
  // access pattern here has no reuse structure worth modelling.
  if (cache.size >= CACHE_MAX) {
    const oldest = cache.keys().next().value
    if (oldest !== undefined) cache.delete(oldest)
  }
  cache.set(path, {source,result:r})
  return r
}

/**
 * Compile edited source, bypassing the cache.
 *
 * The cache is keyed by spec path, and edited text is not that spec any more --
 * caching it would serve a stale tree the moment someone typed.
 */
export async function analyzeEdited(source: string): Promise<T27Analysis> {
  return analyze(source)
}

/** Compile ahead of a click. Users hover 80-150ms before selecting. */
export async function prefetchSpec(path: string): Promise<void> {
  if (cache.has(path)) return
  try {
    const src = await loadSpecSource(path)
    await analyzeCached(path, src)
  } catch {
    // A failed prefetch must stay silent: the click path will surface it.
  }
}

let manifestPromise:Promise<SpecManifest>|null=null
export function loadManifest(): Promise<SpecManifest> {
  if(!manifestPromise)manifestPromise=fetch('t27/manifest.json',{credentials:'omit'}).then(async res=>{
    if (!res.ok) throw new Error(`could not fetch spec manifest (${res.status})`)
    return res.json() as Promise<SpecManifest>
  }).catch(error=>{manifestPromise=null;throw error})
  return manifestPromise
}

export async function loadSpecSource(path: string,expectedSha256?:string): Promise<string> {
  specExplorerHash(path,{sha256:expectedSha256})
  resolveManifestSpec(await loadManifest(),path)
  const res = await fetch(`t27/files/${path.split('/').map(encodeURIComponent).join('/')}`,{credentials:'omit'})
  if (!res.ok) throw new Error(`could not fetch spec ${path} (${res.status})`)
  const bytes=await res.arrayBuffer()
  if(expectedSha256){
    const hash=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes)),b=>b.toString(16).padStart(2,'0')).join('')
    if(hash!==expectedSha256)throw new Error(`Spec SHA-256 mismatch: ${path}`)
  }
  return new TextDecoder().decode(bytes)
}
