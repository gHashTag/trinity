// Spec Explorer -- the .t27 corpus, layer by layer.
//
// Pick any spec from the library and watch it through every stage the real
// compiler puts it through: tokens, AST, type check, HIR, and five codegen
// backends. The compiler is not reimplemented here -- `bootstrap/src/compiler.rs`
// is built to WebAssembly and run in the browser, so what this page draws is
// what `t27c` produces, and it cannot drift.
//
// Deliberately not using Monaco (already a dependency, used by /play): a
// hand-rolled line-numbered view lets an AST node highlight the source line it
// came from, and avoids Monaco's CDN fetch on a page that already loads a
// 477 KB wasm module.

import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { Link } from 'react-router-dom'
import { useI18n } from '../i18n/context'
import { usePageMeta } from '../hooks/usePageMeta'
import {
  analyze,
  loadManifest,
  loadSpecSource,
  type SpecEntry,
  type SpecManifest,
  type T27Analysis,
  type T27Node,
} from '../lib/t27Compiler'

const UI = {
  en: {
    title: 'Spec Explorer',
    subtitle: 'Every .t27 spec, layer by layer',
    metaTitle: 'Spec Explorer',
    metaDescription:
      'Browse the whole t27 spec corpus and watch each spec through the real compiler: tokens, AST, HIR and five codegen backends.',
    search: 'Search specs',
    allCategories: 'All categories',
    specs: 'specs',
    loading: 'Loading compiler…',
    compiling: 'Analysing…',
    back: '← Home',
    source: 'Source',
    tokens: 'Tokens',
    ast: 'AST',
    hir: 'HIR',
    lines: 'lines',
    nodes: 'nodes',
    depth: 'depth',
    topLevel: 'top-level',
    bytes: 'bytes',
    expandAll: 'Expand all',
    collapseAll: 'Collapse all',
    noResults: 'No spec matches that search.',
    pickSpec: 'Pick a spec from the library to see it through every layer.',
    typecheckOk: 'Type check passed',
    typecheckFail: 'Type check errors',
    typecheckSkipped: 'Note: no codegen path runs the type checker — t27c compile gates on it, t27c gen does not.',
    lossTitle: 'The parser dropped part of this file',
    lossBody:
      'Error recovery discarded declarations while still reporting a successful parse. The tree below is missing them.',
    discarded: 'discarded declarations',
    swallowed: 'swallowed constructs',
    lexBad: 'characters the lexer dropped',
    noHir: 'This spec produces no hardware IR.',
    targetFailed: 'This backend rejected the spec:',
    emptyOut: 'This backend produced no output.',
    showingFirst: 'Showing the first',
    ofTokens: 'of',
    showAll: 'Show all',
    provenance: 'Corpus and compiler vendored from',
    snapshotDirty: 'snapshot includes uncommitted changes',
    wasmNote: 'Real compiler, run in your browser',
    took: 'took',
    astEmpty: 'The parser returned no tree for this spec.',
    filterKind: 'Filter by node kind',
    clear: 'Clear',
    matchedNodes: 'matching nodes',
  },
  ru: {
    title: 'Обозреватель спек',
    subtitle: 'Каждая .t27-спека, слой за слоем',
    metaTitle: 'Обозреватель спек',
    metaDescription:
      'Просмотр всего корпуса спек t27 и каждой спеки через настоящий компилятор: токены, AST, HIR и пять бэкендов кодогенерации.',
    search: 'Поиск по спекам',
    allCategories: 'Все категории',
    specs: 'спек',
    loading: 'Загрузка компилятора…',
    compiling: 'Анализ…',
    back: '← На главную',
    source: 'Исходник',
    tokens: 'Токены',
    ast: 'AST',
    hir: 'HIR',
    lines: 'строк',
    nodes: 'узлов',
    depth: 'глубина',
    topLevel: 'верхний уровень',
    bytes: 'байт',
    expandAll: 'Развернуть всё',
    collapseAll: 'Свернуть всё',
    noResults: 'Ни одна спека не подходит под запрос.',
    pickSpec: 'Выберите спеку из библиотеки, чтобы увидеть её на всех слоях.',
    typecheckOk: 'Проверка типов пройдена',
    typecheckFail: 'Ошибки проверки типов',
    typecheckSkipped: 'Заметьте: ни один путь кодогенерации не запускает проверку типов — t27c compile её требует, t27c gen нет.',
    lossTitle: 'Парсер отбросил часть этого файла',
    lossBody:
      'Восстановление после ошибок отбросило объявления, но парсинг всё равно отмечен успешным. В дереве ниже их нет.',
    discarded: 'отброшенных объявлений',
    swallowed: 'проглоченных конструкций',
    lexBad: 'символов отброшено лексером',
    noHir: 'Эта спека не даёт аппаратного IR.',
    targetFailed: 'Этот бэкенд отклонил спеку:',
    emptyOut: 'Этот бэкенд не выдал ничего.',
    showingFirst: 'Показаны первые',
    ofTokens: 'из',
    showAll: 'Показать все',
    provenance: 'Корпус и компилятор взяты из',
    snapshotDirty: 'снимок включает незакоммиченные изменения',
    wasmNote: 'Настоящий компилятор, запущенный в вашем браузере',
    took: 'за',
    astEmpty: 'Парсер не вернул дерево для этой спеки.',
    filterKind: 'Фильтр по типу узла',
    clear: 'Сбросить',
    matchedNodes: 'подходящих узлов',
  },
} as const

type Ui = Record<keyof typeof UI.en, string>

const C = {
  bg: '#000000',
  panel: '#0a0a0a',
  raised: '#111111',
  border: 'rgba(255,255,255,0.10)',
  borderBright: 'rgba(255,255,255,0.20)',
  text: '#FFFFFF',
  muted: '#888888',
  accent: '#00FF88',
  golden: '#FFD700',
  bad: '#f85149',
  warn: '#f0a020',
  mono: "'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, monospace",
}

/** Colour a node by its family so structure reads at a glance. */
function kindColor(kind: string): string {
  if (kind.startsWith('Expr')) return C.accent
  if (kind.startsWith('Stmt')) return '#58a6ff'
  if (kind.endsWith('Decl') || kind === 'Module') return C.golden
  if (kind.endsWith('Block') || kind === 'EnumVariant') return '#c792ea'
  return C.muted
}

const LAYERS = [
  { id: 'source', kind: 'source' },
  { id: 'tokens', kind: 'tokens' },
  { id: 'ast', kind: 'ast' },
  { id: 'typecheck', kind: 'typecheck' },
  { id: 'hir', kind: 'hir' },
  { id: 'zig', kind: 'target' },
  { id: 'verilog', kind: 'target' },
  { id: 'verilog_hir', kind: 'target' },
  { id: 'c', kind: 'target' },
  { id: 'rust', kind: 'target' },
] as const

type LayerId = (typeof LAYERS)[number]['id']

const LAYER_LABEL: Record<LayerId, string> = {
  source: 'Source',
  tokens: 'Tokens',
  ast: 'AST',
  typecheck: 'Types',
  hir: 'HIR',
  zig: 'Zig',
  verilog: 'Verilog',
  verilog_hir: 'Verilog (HIR)',
  c: 'C',
  rust: 'Rust',
}

// ---------------------------------------------------------------- AST tree

interface AstRowProps {
  node: T27Node
  depth: number
  path: string
  open: Set<string>
  toggle: (path: string) => void
  onHover: (line: number | null) => void
  filter: string
}

function AstRow({ node, depth, path, open, toggle, onHover, filter }: AstRowProps) {
  const hasKids = node.children.length > 0
  const isOpen = open.has(path)
  const dim = filter.length > 0 && !node.kind.toLowerCase().includes(filter.toLowerCase())

  const scalars: [string, string][] = []
  if (node.name) scalars.push(['name', node.name])
  if (node.value) scalars.push(['value', node.value])
  if (node.type) scalars.push(['type', node.type])
  if (node.op) scalars.push(['op', node.op])
  if (node.returnType) scalars.push(['→', node.returnType])
  if (node.field) scalars.push(['field', node.field])

  return (
    <div>
      <div
        onMouseEnter={() => onHover(node.line)}
        onMouseLeave={() => onHover(null)}
        onClick={() => hasKids && toggle(path)}
        style={{
          display: 'flex',
          alignItems: 'baseline',
          gap: 8,
          padding: '1px 6px',
          paddingLeft: 6 + depth * 14,
          cursor: hasKids ? 'pointer' : 'default',
          opacity: dim ? 0.25 : 1,
          borderRadius: 3,
          fontSize: 12.5,
          lineHeight: 1.65,
          fontFamily: C.mono,
        }}
      >
        <span style={{ width: 10, flexShrink: 0, color: C.muted, fontSize: 9 }}>
          {hasKids ? (isOpen ? '▾' : '▸') : ''}
        </span>
        <span style={{ color: kindColor(node.kind), fontWeight: 600 }}>{node.kind}</span>
        {scalars.map(([k, v]) => (
          <span key={k} style={{ color: C.muted, whiteSpace: 'nowrap' }}>
            {k}=<span style={{ color: '#d8d8d8' }}>{v.length > 40 ? v.slice(0, 40) + '…' : v}</span>
          </span>
        ))}
        {node.params && node.params.length > 0 && (
          <span style={{ color: C.muted }}>({node.params.map((p) => `${p.name}: ${p.type}`).join(', ')})</span>
        )}
        {hasKids && !isOpen && (
          <span style={{ color: C.muted, opacity: 0.6 }}>{node.children.length}</span>
        )}
        <span style={{ marginLeft: 'auto', color: C.muted, opacity: 0.5, fontSize: 11, flexShrink: 0 }}>
          {node.line || ''}
        </span>
      </div>
      {hasKids && isOpen && (
        <div>
          {node.children.map((c, i) => (
            <AstRow
              key={i}
              node={c}
              depth={depth + 1}
              path={`${path}.${i}`}
              open={open}
              toggle={toggle}
              onHover={onHover}
              filter={filter}
            />
          ))}
        </div>
      )}
    </div>
  )
}

// ------------------------------------------------------------------- page

export default function SpecExplorer() {
  const { lang } = useI18n()
  const ui: Ui = lang === 'ru' ? UI.ru : UI.en
  usePageMeta(ui.metaTitle, ui.metaDescription)

  const [manifest, setManifest] = useState<SpecManifest | null>(null)
  const [query, setQuery] = useState('')
  const [category, setCategory] = useState<string>('')
  const [selected, setSelected] = useState<SpecEntry | null>(null)
  const [source, setSource] = useState('')
  const [result, setResult] = useState<T27Analysis | null>(null)
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState<string | null>(null)
  const [layer, setLayer] = useState<LayerId>('ast')
  const [open, setOpen] = useState<Set<string>>(new Set())
  const [hoverLine, setHoverLine] = useState<number | null>(null)
  const [kindFilter, setKindFilter] = useState('')
  const [tokenLimit, setTokenLimit] = useState(400)
  const [ms, setMs] = useState<number | null>(null)
  const sourceRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    loadManifest().then(setManifest).catch((e) => setErr(String(e)))
  }, [])

  const filtered = useMemo(() => {
    if (!manifest) return []
    const q = query.trim().toLowerCase()
    return manifest.specs.filter((s) => {
      if (category && s.category !== category) return false
      if (!q) return true
      return (
        s.path.toLowerCase().includes(q) ||
        s.name.toLowerCase().includes(q) ||
        (s.module ? s.module.toLowerCase().includes(q) : false)
      )
    })
  }, [manifest, query, category])

  const pick = useCallback(async (spec: SpecEntry) => {
    setSelected(spec)
    setBusy(true)
    setErr(null)
    setResult(null)
    setTokenLimit(400)
    try {
      const text = await loadSpecSource(spec.path)
      setSource(text)
      const t0 = performance.now()
      const r = await analyze(text)
      setMs(performance.now() - t0)
      setResult(r)
      // Open the root and its immediate children: enough to show the shape of
      // the module without rendering thousands of rows on a large spec.
      const seed = new Set<string>(['0'])
      r.ast?.children.forEach((_, i) => seed.add(`0.${i}`))
      setOpen(seed)
    } catch (e) {
      setErr(String(e))
    } finally {
      setBusy(false)
    }
  }, [])

  const toggle = useCallback((path: string) => {
    setOpen((prev) => {
      const next = new Set(prev)
      if (next.has(path)) next.delete(path)
      else next.add(path)
      return next
    })
  }, [])

  const expandAll = useCallback(() => {
    if (!result?.ast) return
    const all = new Set<string>()
    const walk = (n: T27Node, p: string) => {
      if (n.children.length) all.add(p)
      n.children.forEach((c, i) => walk(c, `${p}.${i}`))
    }
    walk(result.ast, '0')
    setOpen(all)
  }, [result])

  const kindCounts = useMemo(() => {
    if (!result?.ast) return []
    const counts = new Map<string, number>()
    const walk = (n: T27Node) => {
      counts.set(n.kind, (counts.get(n.kind) || 0) + 1)
      n.children.forEach(walk)
    }
    walk(result.ast)
    return [...counts.entries()].sort((a, b) => b[1] - a[1])
  }, [result])

  const sourceLines = useMemo(() => source.split('\n'), [source])

  useEffect(() => {
    if (hoverLine && sourceRef.current && layer === 'source') {
      const el = sourceRef.current.querySelector(`[data-line="${hoverLine}"]`)
      el?.scrollIntoView({ block: 'nearest' })
    }
  }, [hoverLine, layer])

  const lossCount =
    (result?.discarded.length || 0) + (result?.swallowed.length || 0) + (result?.lexerDiscarded.length || 0)

  const box: React.CSSProperties = {
    background: C.panel,
    border: `1px solid ${C.border}`,
    borderRadius: 6,
  }

  return (
    <div
      style={{
        height: '100dvh',
        display: 'flex',
        flexDirection: 'column',
        background: C.bg,
        color: C.text,
        fontFamily: "'Outfit', system-ui, sans-serif",
        overflow: 'hidden',
      }}
    >
      {/* header */}
      <header
        style={{
          height: 52,
          flexShrink: 0,
          borderBottom: `1px solid ${C.border}`,
          display: 'flex',
          alignItems: 'center',
          gap: 16,
          padding: '0 16px',
        }}
      >
        <Link to="/" style={{ color: C.muted, textDecoration: 'none', fontSize: 13 }}>
          {ui.back}
        </Link>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 10, minWidth: 0 }}>
          <span style={{ fontSize: 16, fontWeight: 700, color: C.golden }}>{ui.title}</span>
          <span style={{ fontSize: 12, color: C.muted, whiteSpace: 'nowrap' }}>{ui.subtitle}</span>
        </div>
        <div style={{ marginLeft: 'auto', display: 'flex', alignItems: 'center', gap: 14, fontSize: 11, color: C.muted }}>
          <span style={{ color: C.accent }}>◆ {ui.wasmNote}</span>
          {manifest && (
            <span style={{ fontFamily: C.mono }}>
              {ui.provenance} {manifest.generatedFrom.repo}@{manifest.generatedFrom.shortCommit}
              {manifest.generatedFrom.specsOrCompilerDirty ? ` (${ui.snapshotDirty})` : ''}
            </span>
          )}
        </div>
      </header>

      <div style={{ flex: 1, display: 'flex', minHeight: 0 }}>
        {/* library */}
        <aside
          style={{
            width: 300,
            flexShrink: 0,
            borderRight: `1px solid ${C.border}`,
            display: 'flex',
            flexDirection: 'column',
            minHeight: 0,
          }}
        >
          <div style={{ padding: 10, display: 'flex', flexDirection: 'column', gap: 8 }}>
            <input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder={ui.search}
              aria-label={ui.search}
              style={{
                background: C.raised,
                border: `1px solid ${C.border}`,
                borderRadius: 4,
                color: C.text,
                padding: '7px 9px',
                fontSize: 13,
                fontFamily: 'inherit',
                outline: 'none',
              }}
            />
            <select
              value={category}
              onChange={(e) => setCategory(e.target.value)}
              aria-label={ui.allCategories}
              style={{
                background: C.raised,
                border: `1px solid ${C.border}`,
                borderRadius: 4,
                color: C.text,
                padding: '6px 8px',
                fontSize: 12.5,
                fontFamily: 'inherit',
                outline: 'none',
              }}
            >
              <option value="">
                {ui.allCategories} ({manifest?.specCount ?? 0})
              </option>
              {manifest &&
                Object.entries(manifest.categories).map(([c, n]) => (
                  <option key={c} value={c}>
                    {c} ({n})
                  </option>
                ))}
            </select>
            <div style={{ fontSize: 11, color: C.muted, fontFamily: C.mono }}>
              {filtered.length} {ui.specs}
            </div>
          </div>

          <div style={{ flex: 1, overflowY: 'auto', minHeight: 0 }}>
            {filtered.length === 0 && manifest && (
              <div style={{ padding: 14, fontSize: 12.5, color: C.muted }}>{ui.noResults}</div>
            )}
            {filtered.map((s) => {
              const active = selected?.path === s.path
              return (
                <button
                  key={s.path}
                  onClick={() => pick(s)}
                  // The visible label is two nested divs, which leaves the
                  // button with no accessible name -- spell it out.
                  aria-label={`${s.module || s.name} — ${s.path}, ${s.lines} ${ui.lines}`}
                  aria-current={active ? 'true' : undefined}
                  style={{
                    display: 'block',
                    width: '100%',
                    textAlign: 'left',
                    background: active ? 'rgba(0,255,136,0.10)' : 'transparent',
                    border: 'none',
                    borderLeft: `2px solid ${active ? C.accent : 'transparent'}`,
                    color: active ? C.accent : C.text,
                    padding: '6px 10px',
                    cursor: 'pointer',
                    fontFamily: C.mono,
                    fontSize: 12,
                  }}
                >
                  <div style={{ whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                    {s.module || s.name}
                  </div>
                  <div style={{ color: C.muted, fontSize: 10.5, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                    {s.path} · {s.lines}
                  </div>
                </button>
              )
            })}
          </div>
        </aside>

        {/* main */}
        <main style={{ flex: 1, display: 'flex', flexDirection: 'column', minWidth: 0, minHeight: 0 }}>
          {err && (
            <div style={{ padding: 14, color: C.bad, fontFamily: C.mono, fontSize: 13 }}>{err}</div>
          )}

          {!selected && !err && (
            <div style={{ margin: 'auto', color: C.muted, fontSize: 14, textAlign: 'center', padding: 24 }}>
              {manifest ? ui.pickSpec : ui.loading}
            </div>
          )}

          {selected && (
            <>
              {/* stats */}
              <div
                style={{
                  flexShrink: 0,
                  padding: '9px 14px',
                  borderBottom: `1px solid ${C.border}`,
                  display: 'flex',
                  alignItems: 'center',
                  gap: 18,
                  flexWrap: 'wrap',
                  fontFamily: C.mono,
                  fontSize: 11.5,
                  color: C.muted,
                }}
              >
                <span style={{ color: C.golden, fontWeight: 600 }}>{selected.path}</span>
                {busy && <span style={{ color: C.accent }}>{ui.compiling}</span>}
                {result && (
                  <>
                    <span>{result.sourceLines} {ui.lines}</span>
                    <span>{result.tokenCount} {ui.tokens.toLowerCase()}</span>
                    {result.nodeCount !== undefined && (
                      <span>{result.nodeCount} {ui.nodes} / {ui.depth} {result.astDepth}</span>
                    )}
                    {ms !== null && <span style={{ opacity: 0.7 }}>{ui.took} {ms.toFixed(0)}ms</span>}
                  </>
                )}
              </div>

              {/* loss banner -- the honest bit */}
              {result && lossCount > 0 && (
                <div
                  style={{
                    flexShrink: 0,
                    margin: '10px 14px 0',
                    padding: '9px 12px',
                    background: 'rgba(248,81,73,0.10)',
                    border: `1px solid ${C.bad}`,
                    borderRadius: 5,
                    fontSize: 12,
                  }}
                >
                  <div style={{ color: C.bad, fontWeight: 700, marginBottom: 3 }}>⚠ {ui.lossTitle}</div>
                  <div style={{ color: '#d8d8d8', marginBottom: 5 }}>{ui.lossBody}</div>
                  <div style={{ color: C.muted, fontFamily: C.mono, fontSize: 11 }}>
                    {result.discarded.length} {ui.discarded} · {result.swallowed.length} {ui.swallowed} ·{' '}
                    {result.lexerDiscarded.length} {ui.lexBad}
                  </div>
                </div>
              )}

              {/* layer tabs */}
              <div
                style={{
                  flexShrink: 0,
                  display: 'flex',
                  gap: 2,
                  padding: '10px 14px 0',
                  overflowX: 'auto',
                }}
              >
                {LAYERS.map((l) => {
                  const t = l.kind === 'target' ? result?.targets?.[l.id] : null
                  const failed = l.kind === 'target' && result && t && !t.ok
                  const active = layer === l.id
                  return (
                    <button
                      key={l.id}
                      onClick={() => setLayer(l.id)}
                      style={{
                        background: active ? C.raised : 'transparent',
                        border: `1px solid ${active ? C.borderBright : 'transparent'}`,
                        borderBottom: active ? `1px solid ${C.bg}` : `1px solid ${C.border}`,
                        borderRadius: '5px 5px 0 0',
                        color: failed ? C.bad : active ? C.accent : C.muted,
                        padding: '6px 12px',
                        cursor: 'pointer',
                        fontSize: 12.5,
                        fontFamily: 'inherit',
                        whiteSpace: 'nowrap',
                      }}
                    >
                      {LAYER_LABEL[l.id]}
                      {failed ? ' ✕' : ''}
                    </button>
                  )
                })}
              </div>

              {/* layer body */}
              <div style={{ flex: 1, minHeight: 0, padding: '0 14px 14px', display: 'flex' }}>
                <div style={{ ...box, flex: 1, minHeight: 0, overflow: 'auto', borderTopLeftRadius: 0 }}>
                  {/* source */}
                  {layer === 'source' && (
                    <div ref={sourceRef} style={{ fontFamily: C.mono, fontSize: 12.5, lineHeight: 1.6 }}>
                      {sourceLines.map((l, i) => (
                        <div
                          key={i}
                          data-line={i + 1}
                          style={{
                            display: 'flex',
                            background: hoverLine === i + 1 ? 'rgba(255,215,0,0.13)' : 'transparent',
                          }}
                        >
                          <span
                            style={{
                              width: 46,
                              flexShrink: 0,
                              textAlign: 'right',
                              paddingRight: 12,
                              color: C.muted,
                              opacity: 0.45,
                              userSelect: 'none',
                            }}
                          >
                            {i + 1}
                          </span>
                          <span style={{ whiteSpace: 'pre-wrap', wordBreak: 'break-word' }}>{l || ' '}</span>
                        </div>
                      ))}
                    </div>
                  )}

                  {/* tokens */}
                  {layer === 'tokens' && result && (
                    <div style={{ padding: 8 }}>
                      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 4 }}>
                        {result.tokens.slice(0, tokenLimit).map((t, i) => (
                          <span
                            key={i}
                            title={`${t.kind} @ ${t.line}:${t.col}`}
                            onMouseEnter={() => setHoverLine(t.line)}
                            onMouseLeave={() => setHoverLine(null)}
                            style={{
                              display: 'inline-flex',
                              flexDirection: 'column',
                              gap: 1,
                              padding: '3px 6px',
                              background: C.raised,
                              border: `1px solid ${C.border}`,
                              borderRadius: 3,
                              fontFamily: C.mono,
                              fontSize: 11,
                            }}
                          >
                            <span style={{ color: C.accent }}>
                              {t.lexeme.length > 18 ? t.lexeme.slice(0, 18) + '…' : t.lexeme || '␠'}
                            </span>
                            <span style={{ color: C.muted, fontSize: 9.5 }}>{t.kind}</span>
                          </span>
                        ))}
                      </div>
                      {result.tokens.length > tokenLimit && (
                        <div style={{ marginTop: 12, fontSize: 12, color: C.muted }}>
                          {ui.showingFirst} {tokenLimit} {ui.ofTokens} {result.tokens.length}.{' '}
                          <button
                            onClick={() => setTokenLimit(result.tokens.length)}
                            style={{
                              background: 'transparent',
                              border: `1px solid ${C.border}`,
                              borderRadius: 4,
                              color: C.accent,
                              padding: '3px 9px',
                              cursor: 'pointer',
                              fontSize: 12,
                              fontFamily: 'inherit',
                            }}
                          >
                            {ui.showAll}
                          </button>
                        </div>
                      )}
                    </div>
                  )}

                  {/* ast */}
                  {layer === 'ast' && result && (
                    <div>
                      <div
                        style={{
                          position: 'sticky',
                          top: 0,
                          zIndex: 1,
                          background: C.panel,
                          borderBottom: `1px solid ${C.border}`,
                          padding: '7px 10px',
                          display: 'flex',
                          alignItems: 'center',
                          gap: 8,
                          flexWrap: 'wrap',
                        }}
                      >
                        <button onClick={expandAll} style={ctrlBtn}>{ui.expandAll}</button>
                        <button onClick={() => setOpen(new Set(['0']))} style={ctrlBtn}>{ui.collapseAll}</button>
                        <input
                          value={kindFilter}
                          onChange={(e) => setKindFilter(e.target.value)}
                          placeholder={ui.filterKind}
                          aria-label={ui.filterKind}
                          style={{
                            background: C.raised,
                            border: `1px solid ${C.border}`,
                            borderRadius: 4,
                            color: C.text,
                            padding: '4px 8px',
                            fontSize: 12,
                            fontFamily: C.mono,
                            outline: 'none',
                            width: 160,
                          }}
                        />
                        <div style={{ display: 'flex', gap: 5, flexWrap: 'wrap', marginLeft: 'auto' }}>
                          {kindCounts.slice(0, 8).map(([k, n]) => (
                            <button
                              key={k}
                              onClick={() => setKindFilter(kindFilter === k ? '' : k)}
                              style={{
                                background: kindFilter === k ? 'rgba(0,255,136,0.14)' : 'transparent',
                                border: `1px solid ${C.border}`,
                                borderRadius: 3,
                                color: kindColor(k),
                                padding: '2px 6px',
                                cursor: 'pointer',
                                fontSize: 10.5,
                                fontFamily: C.mono,
                              }}
                            >
                              {k} {n}
                            </button>
                          ))}
                        </div>
                      </div>
                      {result.ast ? (
                        <div style={{ padding: '6px 0' }}>
                          <AstRow
                            node={result.ast}
                            depth={0}
                            path="0"
                            open={open}
                            toggle={toggle}
                            onHover={setHoverLine}
                            filter={kindFilter}
                          />
                        </div>
                      ) : (
                        <div style={{ padding: 14, color: C.bad, fontFamily: C.mono, fontSize: 12.5 }}>
                          {result.astError || ui.astEmpty}
                        </div>
                      )}
                    </div>
                  )}

                  {/* typecheck */}
                  {layer === 'typecheck' && result && (
                    <div style={{ padding: 14, fontSize: 13 }}>
                      {result.typecheck?.fatal ? (
                        <div style={{ color: C.bad, fontFamily: C.mono }}>{result.typecheck.fatal}</div>
                      ) : (
                        <>
                          <div
                            style={{
                              color: result.typecheck?.ok ? C.accent : C.bad,
                              fontWeight: 700,
                              marginBottom: 8,
                            }}
                          >
                            {result.typecheck?.ok ? `✓ ${ui.typecheckOk}` : `✕ ${ui.typecheckFail}`}
                            {' · '}
                            <span style={{ fontFamily: C.mono, fontWeight: 400 }}>
                              {result.typecheck?.errorCount ?? 0} / {result.typecheck?.warnings ?? 0} warn
                            </span>
                          </div>
                          <div style={{ color: C.warn, fontSize: 12, marginBottom: 12 }}>{ui.typecheckSkipped}</div>
                          {result.typecheck?.errors?.map((e, i) => (
                            <div
                              key={i}
                              style={{ fontFamily: C.mono, fontSize: 12, color: '#d8d8d8', padding: '2px 0' }}
                            >
                              {e}
                            </div>
                          ))}
                        </>
                      )}
                    </div>
                  )}

                  {/* hir */}
                  {layer === 'hir' && result && (
                    <pre style={preStyle}>
                      {result.hir.ok ? result.hir.text || ui.noHir : `${ui.targetFailed}\n\n${result.hir.error}`}
                    </pre>
                  )}

                  {/* codegen targets */}
                  {LAYERS.find((l) => l.id === layer)?.kind === 'target' && result && (
                    <>
                      {(() => {
                        const t = result.targets[layer]
                        if (!t) return <div style={{ padding: 14, color: C.muted }}>{ui.emptyOut}</div>
                        if (!t.ok)
                          return (
                            <pre style={{ ...preStyle, color: C.bad }}>
                              {ui.targetFailed}
                              {'\n\n'}
                              {t.error}
                            </pre>
                          )
                        return <pre style={preStyle}>{t.code || ui.emptyOut}</pre>
                      })()}
                    </>
                  )}
                </div>
              </div>
            </>
          )}
        </main>
      </div>
    </div>
  )
}

const ctrlBtn: React.CSSProperties = {
  background: 'transparent',
  border: `1px solid ${C.border}`,
  borderRadius: 4,
  color: C.muted,
  padding: '3px 9px',
  cursor: 'pointer',
  fontSize: 11.5,
  fontFamily: 'inherit',
}

const preStyle: React.CSSProperties = {
  margin: 0,
  padding: 14,
  fontFamily: C.mono,
  fontSize: 12.5,
  lineHeight: 1.6,
  color: '#d8d8d8',
  whiteSpace: 'pre-wrap',
  wordBreak: 'break-word',
}
