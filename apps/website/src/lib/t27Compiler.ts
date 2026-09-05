// Browser-side driver for the real t27 compiler, compiled to WebAssembly.
//
// The wasm module is `bootstrap/src/compiler.rs` built for
// wasm32-unknown-unknown -- the same code the CLI runs, not a reimplementation.
// See apps/website/scripts/sync-t27-specs.mjs for how the artifact gets here.

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
  specs: SpecEntry[]
}

interface Exports {
  memory: WebAssembly.Memory
  t27_alloc: (len: number) => number
  t27_free: (ptr: number, len: number) => void
  t27_analyze: (ptr: number, len: number) => number
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

/** Run one .t27 source through every pipeline layer. */
export async function analyze(source: string): Promise<T27Analysis> {
  const wasm = await loadCompiler()
  const bytes = new TextEncoder().encode(source)
  const inPtr = wasm.t27_alloc(bytes.length)
  new Uint8Array(wasm.memory.buffer, inPtr, bytes.length).set(bytes)

  // t27_analyze takes ownership of the input allocation and returns a
  // length-prefixed blob: [u32 LE byte length][utf8 json].
  const outPtr = wasm.t27_analyze(inPtr, bytes.length)
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
const cache = new Map<string, T27Analysis>()
const CACHE_MAX = 24

export function cachedAnalysis(path: string): T27Analysis | undefined {
  return cache.get(path)
}

export async function analyzeCached(path: string, source: string): Promise<T27Analysis> {
  const hit = cache.get(path)
  if (hit) return hit
  const r = await analyze(source)
  // Plain FIFO eviction: these are a few hundred KB each at worst and the
  // access pattern here has no reuse structure worth modelling.
  if (cache.size >= CACHE_MAX) {
    const oldest = cache.keys().next().value
    if (oldest !== undefined) cache.delete(oldest)
  }
  cache.set(path, r)
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

export async function loadManifest(): Promise<SpecManifest> {
  const res = await fetch('t27/manifest.json')
  if (!res.ok) throw new Error(`could not fetch spec manifest (${res.status})`)
  return res.json()
}

export async function loadSpecSource(path: string): Promise<string> {
  const res = await fetch(`t27/files/${path}`)
  if (!res.ok) throw new Error(`could not fetch spec ${path} (${res.status})`)
  return res.text()
}
