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
import { SpecCodeView } from '../components/SpecCodeView'
import { HealthBar, HealthDot, PipelineRibbon, HEALTH_COLOR } from '../components/SpecGraphics'
import { highlightCode, highlightSource, type Span } from '../lib/highlight'
import {
  analyzeCached,
  cachedAnalysis,
  loadCompiler,
  loadManifest,
  loadSpecSource,
  prefetchSpec,
  type Health,
  type SpecEntry,
  type SpecManifest,
  type T27Analysis,
  type T27Node,
} from '../lib/t27Compiler'

/** Shape as well as colour, so status survives a colour-blind reader. */
const HEALTH_GLYPH: Record<Health, string> = { ok: '✓', warn: '⚠', fail: '✕' }

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
    copy: 'Copy',
    copied: 'Copied',
    highlightNote: 'Coloured from the compiler’s own token stream',
    generated: 'generated',
    working: 'Working',
    warnings: 'Warnings',
    broken: 'Broken',
    all: 'All',
    healthOk: 'Clean through every layer',
    healthWarn: 'Compiles, but the compiler flagged or dropped something',
    healthFail: 'A backend refused this spec outright',
    corpusHealth: 'corpus health',
    startHere: 'START HERE',
    noneInGroup: 'Nothing in this group.',
    lesson: 'LESSON',
    course: 'Course',
    courseNote: 'Eight lessons, in order, each one clean through every layer.',
    droppedItems: 'dropped',
    typeErrs: 'type errors',
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
    copy: 'Копировать',
    copied: 'Скопировано',
    highlightNote: 'Раскрашено по собственному потоку токенов компилятора',
    generated: 'сгенерировано',
    working: 'Рабочие',
    warnings: 'С замечаниями',
    broken: 'Сломанные',
    all: 'Все',
    healthOk: 'Чисто на всех слоях',
    healthWarn: 'Компилируется, но компилятор что-то отбросил или пометил',
    healthFail: 'Бэкенд отказался обрабатывать эту спеку',
    corpusHealth: 'здоровье корпуса',
    startHere: 'НАЧНИТЕ ЗДЕСЬ',
    noneInGroup: 'В этой группе пусто.',
    lesson: 'УРОК',
    course: 'Курс',
    courseNote: 'Восемь уроков по порядку, каждый чист на всех слоях.',
    droppedItems: 'отброшено',
    typeErrs: 'ошибок типов',
  },
} as const

type Ui = Record<keyof typeof UI.en, string>

// The site's tokens (index.css :root) rather than a stock editor palette.
// Panels sit a step above pure black: on OLED, white text on #000 smears
// during scroll, and this list scrolls a lot.
const C = {
  bg: '#000000',
  panel: '#0b0d0c',
  raised: '#121614',
  border: 'rgba(0,255,136,0.10)',
  borderBright: 'rgba(0,255,136,0.34)',
  text: '#FFFFFF',
  muted: '#8b9490',
  accent: '#00FF88',
  golden: '#FFD700',
  bad: '#f85149',
  warn: '#f0a020',
  mono: "'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, monospace",
}

function fmtBytes(n: number): string {
  if (n < 1024) return `${n}B`
  return `${(n / 1024).toFixed(1)}K`
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
  // Healthy specs first, by default: this is a catalogue to browse, not a
  // triage queue. The problem groups are one click away and carry their counts.
  const [healthFilter, setHealthFilter] = useState<Health | 'all' | 'course'>('ok')
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
  // `pick` is defined below but needed by the mount effect above; a ref keeps
  // the ordering honest without hoisting the callback out of the component.
  const pickRef = useRef<((s: SpecEntry) => Promise<void>) | null>(null)

  useEffect(() => {
    // Instantiate the compiler at mount, not at first click: instantiation
    // dominates a cold compile, and paying it here makes the first selection
    // as fast as every later one.
    void loadCompiler()
    loadManifest()
      .then((m) => {
        setManifest(m)
        // Open the teaching spec straight away: an empty pane teaches nothing,
        // and this one is small enough to read end to end.
        const first = m.specs.find((s) => s.featured) ?? m.specs[0]
        if (first) void pickRef.current?.(first)
      })
      .catch((e) => setErr(String(e)))
  }, [])

  // Inline styles cannot carry media queries, and the header has three pieces
  // of text that will happily overlap rather than wrap. Track the width and
  // drop the optional ones instead.
  const [narrow, setNarrow] = useState(() => (typeof window === 'undefined' ? false : window.innerWidth < 1100))
  useEffect(() => {
    const onResize = () => setNarrow(window.innerWidth < 1100)
    onResize()
    window.addEventListener('resize', onResize)
    return () => window.removeEventListener('resize', onResize)
  }, [])

  const filtered = useMemo(() => {
    if (!manifest) return []
    const q = query.trim().toLowerCase()
    return manifest.specs.filter((s) => {
      if (healthFilter === 'course') {
        if (!s.tutorial) return false
      } else if (healthFilter !== 'all' && s.health !== healthFilter) return false
      if (category && s.category !== category) return false
      if (!q) return true
      return (
        s.path.toLowerCase().includes(q) ||
        s.name.toLowerCase().includes(q) ||
        (s.module ? s.module.toLowerCase().includes(q) : false) ||
        (s.description ? s.description.toLowerCase().includes(q) : false)
      )
    })
  }, [manifest, query, category, healthFilter])

  const pick = useCallback(async (spec: SpecEntry) => {
    // Selection paints immediately -- that sub-100ms response IS the feedback.
    // The previous result deliberately stays on screen while the new one
    // compiles: blanking it would trade real content for a flash of nothing.
    setSelected(spec)
    setErr(null)
    setTokenLimit(400)
    const warm = cachedAnalysis(spec.path)
    setBusy(!warm)
    try {
      const text = await loadSpecSource(spec.path)
      setSource(text)
      const t0 = performance.now()
      const r = await analyzeCached(spec.path, text)
      setMs(warm ? 0 : performance.now() - t0)
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

  pickRef.current = pick

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

  // Highlight the source from the compiler's own tokens -- see lib/highlight.ts.
  const sourceSpans: Span[][] = useMemo(
    () => (result ? highlightSource(source, result.tokens) : source.split('\n').map((l) => [{ text: l, cls: 'plain' as const }])),
    [source, result],
  )

  const activeTarget = LAYERS.find((l) => l.id === layer)?.kind === 'target' ? result?.targets?.[layer] : undefined

  const codeSpans: Span[][] | null = useMemo(() => {
    if (layer === 'hir' && result?.hir.ok && result.hir.text) return highlightCode(result.hir.text, 'verilog')
    if (activeTarget?.ok && activeTarget.code) {
      const langOf: Record<string, string> = {
        zig: 'zig', verilog: 'verilog', verilog_hir: 'verilog', c: 'c', rust: 'rust',
      }
      return highlightCode(activeTarget.code, langOf[layer] || 'plain')
    }
    return null
  }, [layer, result, activeTarget])

  const lossCount =
    (result?.discarded.length || 0) + (result?.swallowed.length || 0) + (result?.lexerDiscarded.length || 0)

  const box: React.CSSProperties = {
    background: C.panel,
    border: `1px solid ${C.border}`,
    borderRadius: 6,
  }

  return (
    <div
      className="spec-x"
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
      {/* Everything after the title is allowed to shrink and then clip: on a
          narrow window the provenance line would otherwise wrap under the
          heading and overlap it. */}
      <header
        style={{
          minHeight: 52,
          flexShrink: 0,
          borderBottom: `1px solid ${C.border}`,
          display: 'flex',
          alignItems: 'center',
          gap: 16,
          padding: '0 16px',
          overflow: 'hidden',
        }}
      >
        <Link to="/" style={{ color: C.muted, textDecoration: 'none', fontSize: 13, flexShrink: 0 }}>
          {ui.back}
        </Link>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 10, minWidth: 0, flexShrink: 0 }}>
          <span style={{ fontSize: 16, fontWeight: 700, color: C.golden, whiteSpace: 'nowrap' }}>{ui.title}</span>
          {!narrow && (
            <span
              style={{
                fontSize: 12,
                color: C.muted,
                whiteSpace: 'nowrap',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
              }}
            >
              {ui.subtitle}
            </span>
          )}
        </div>
        <div
          style={{
            marginLeft: 'auto',
            display: 'flex',
            alignItems: 'center',
            gap: 14,
            fontSize: 11,
            color: C.muted,
            minWidth: 0,
            overflow: 'hidden',
          }}
        >
          {!narrow && <span style={{ color: C.accent, whiteSpace: 'nowrap', flexShrink: 0 }}>◆ {ui.wasmNote}</span>}
          {manifest && (
            <span
              style={{
                fontFamily: C.mono,
                whiteSpace: 'nowrap',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
                minWidth: 0,
              }}
              title={`${manifest.generatedFrom.repo}@${manifest.generatedFrom.commit}`}
            >
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
            // Allowed to shrink on a narrow window rather than pushing the
            // layer panes off-screen entirely.
            minWidth: 180,
            flexShrink: 1,
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
            {/* Counts live inside the filter, so the summary and the
                navigation are one control rather than two that can disagree.
                Every spec is counted once, at its worst stage, so these sum
                to the corpus total. */}
            {manifest && (
              <>
                <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap' }}>
                  {([
                    ['course', ui.course, manifest.specs.filter((s) => s.tutorial).length],
                    ['ok', ui.working, manifest.health.ok],
                    ['warn', ui.warnings, manifest.health.warn],
                    ['fail', ui.broken, manifest.health.fail],
                    ['all', ui.all, manifest.specCount],
                  ] as [Health | 'all' | 'course', string, number][]).map(([k, label, n]) => {
                    const on = healthFilter === k
                    const col = k === 'all' ? C.muted : k === 'course' ? C.golden : HEALTH_COLOR[k]
                    return (
                      <button
                        key={k}
                        onClick={() => setHealthFilter(k)}
                        aria-pressed={on}
                        style={{
                          display: 'flex',
                          alignItems: 'center',
                          gap: 4,
                          background: on ? 'rgba(255,255,255,0.07)' : 'transparent',
                          border: `1px solid ${on ? col : C.border}`,
                          borderRadius: 999,
                          color: on ? col : C.muted,
                          padding: '2px 9px',
                          cursor: 'pointer',
                          fontSize: 11,
                          fontFamily: 'inherit',
                        }}
                      >
                        {k === 'course' ? (
                          <span aria-hidden="true">◆</span>
                        ) : k !== 'all' ? (
                          <span aria-hidden="true">{HEALTH_GLYPH[k]}</span>
                        ) : null}
                        <span>{label}</span>
                        <span style={{ fontFamily: C.mono, opacity: 0.8 }}>{n}</span>
                      </button>
                    )
                  })}
                </div>
                <HealthBar health={manifest.health} total={manifest.specCount} />
              </>
            )}
            <div style={{ fontSize: 11, color: C.muted, fontFamily: C.mono }}>
              {filtered.length} {ui.specs}
            </div>
          </div>

          <div style={{ flex: 1, overflowY: 'auto', minHeight: 0 }}>
            {filtered.length === 0 && manifest && (
              <div style={{ padding: 14, fontSize: 12.5, color: C.muted }}>
                {query || category ? ui.noResults : ui.noneInGroup}
              </div>
            )}
            {filtered.map((s) => {
              const active = selected?.path === s.path
              const dir = s.path.slice(0, s.path.lastIndexOf('/') + 1)
              return (
                <button
                  key={s.path}
                  onClick={() => pick(s)}
                  // Users hover 80-150ms before clicking; that is half the
                  // compile budget, free.
                  onPointerEnter={() => void prefetchSpec(s.path)}
                  onFocus={() => void prefetchSpec(s.path)}
                  // The visible label is nested divs, which leaves the button
                  // with no accessible name -- spell it out.
                  aria-label={`${s.module || s.name} — ${s.path}, ${s.lines} ${ui.lines}, ${s.health}`}
                  aria-current={active ? 'true' : undefined}
                  style={{
                    display: 'flex',
                    gap: 8,
                    width: '100%',
                    textAlign: 'left',
                    background: active ? 'rgba(0,255,136,0.10)' : 'transparent',
                    border: 'none',
                    borderLeft: `2px solid ${active ? C.accent : 'transparent'}`,
                    color: active ? C.accent : C.text,
                    padding: '7px 10px',
                    cursor: 'pointer',
                    fontFamily: C.mono,
                    fontSize: 12,
                    alignItems: 'flex-start',
                  }}
                >
                  <span style={{ paddingTop: 2 }}>
                    <HealthDot health={s.health} />
                  </span>
                  <span style={{ minWidth: 0, flex: 1 }}>
                    <span style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
                      <span style={{ whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', fontWeight: 600 }}>
                        {s.module || s.name}
                      </span>
                      {s.featured ? (
                        <span
                          style={{
                            fontSize: 8.5,
                            letterSpacing: 0.5,
                            color: C.golden,
                            border: `1px solid ${C.golden}`,
                            borderRadius: 3,
                            padding: '0 4px',
                            flexShrink: 0,
                          }}
                        >
                          {ui.startHere}
                        </span>
                      ) : s.tutorial ? (
                        <span
                          style={{
                            fontSize: 8.5,
                            letterSpacing: 0.5,
                            color: C.golden,
                            opacity: 0.75,
                            flexShrink: 0,
                            fontFamily: C.mono,
                          }}
                        >
                          {ui.lesson} {s.lesson}
                        </span>
                      ) : null}
                    </span>
                    {/* Dim the directory, keep the basename readable. */}
                    <span
                      style={{
                        display: 'block',
                        fontSize: 10,
                        whiteSpace: 'nowrap',
                        overflow: 'hidden',
                        textOverflow: 'ellipsis',
                        color: C.muted,
                      }}
                    >
                      <span style={{ opacity: 0.55 }}>{dir}</span>
                      {s.path.slice(dir.length)} · {s.lines}
                    </span>
                    {s.description && (
                      <span
                        style={{
                          display: '-webkit-box',
                          WebkitLineClamp: 2,
                          WebkitBoxOrient: 'vertical',
                          overflow: 'hidden',
                          fontFamily: "'Outfit', system-ui, sans-serif",
                          fontSize: 11,
                          lineHeight: 1.4,
                          color: '#9aa0a6',
                          marginTop: 2,
                        }}
                      >
                        {s.description}
                      </span>
                    )}
                    {s.health !== 'ok' && (
                      <span style={{ display: 'block', fontSize: 10, color: HEALTH_COLOR[s.health], marginTop: 2 }}>
                        {s.failedBackends.length > 0 && `${s.failedBackends.join(', ')} ✕ `}
                        {s.loss > 0 && `${s.loss} ${ui.droppedItems} `}
                        {s.tcErrors > 0 && `${s.tcErrors} ${ui.typeErrs}`}
                      </span>
                    )}
                  </span>
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
                <span style={{ color: HEALTH_COLOR[selected.health] }} title={ui[selected.health === 'ok' ? 'healthOk' : selected.health === 'warn' ? 'healthWarn' : 'healthFail']}>
                  {HEALTH_GLYPH[selected.health]}
                </span>
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

              {/* description + pipeline: what this spec is, and where it dies */}
              {(selected.description || result) && (
                <div
                  style={{
                    flexShrink: 0,
                    padding: '10px 14px 0',
                    display: 'flex',
                    gap: 18,
                    alignItems: 'flex-start',
                    flexWrap: 'wrap',
                  }}
                >
                  {selected.description && (
                    <p style={{ margin: 0, flex: '1 1 320px', minWidth: 0, fontSize: 12.5, lineHeight: 1.55, color: '#b9bfc6', maxWidth: 'none' }}>
                      {selected.description}
                    </p>
                  )}
                  {result && (
                    <div style={{ flex: '0 1 340px', minWidth: 220 }}>
                      <PipelineRibbon
                        result={result}
                        active={layer}
                        onPick={(id) => setLayer(id as LayerId)}
                        labels={LAYER_LABEL}
                      />
                    </div>
                  )}
                </div>
              )}

              {/* loss banner -- the honest bit */}
              {result && lossCount > 0 && (
                <div
                  className="spec-x-banner"
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
                  // A size on the tab makes the backends comparable at a glance
                  // without opening each one.
                  let badge = ''
                  if (result) {
                    if (l.id === 'tokens') badge = String(result.tokenCount)
                    else if (l.id === 'ast') badge = String(result.nodeCount ?? '')
                    else if (l.id === 'typecheck') badge = String(result.typecheck?.errorCount ?? 0)
                    else if (l.id === 'hir') badge = result.hir.ok ? fmtBytes(result.hir.text?.length ?? 0) : '—'
                    else if (t?.ok) badge = fmtBytes(t.bytes ?? 0)
                  }
                  return (
                    <button
                      // Keyed by spec too, so the one-shot failure flash
                      // re-fires when a different spec fails the same backend.
                      key={`${l.id}:${selected.path}`}
                      className={failed ? 'spec-x-flag' : undefined}
                      onClick={() => setLayer(l.id)}
                      aria-current={active ? 'true' : undefined}
                      style={{
                        display: 'flex',
                        alignItems: 'baseline',
                        gap: 6,
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
                      <span>{LAYER_LABEL[l.id]}</span>
                      {failed ? (
                        <span aria-hidden="true">✕</span>
                      ) : badge ? (
                        <span style={{ fontSize: 10, fontFamily: C.mono, opacity: 0.65 }}>{badge}</span>
                      ) : null}
                    </button>
                  )
                })}
              </div>

              {/* layer body */}
              <div style={{ flex: 1, minHeight: 0, padding: '0 14px 14px', display: 'flex' }}>
                <div
                  className="spec-x-pane spec-x-scroll"
                  data-pending={busy ? 'true' : 'false'}
                  style={{ ...box, flex: 1, minHeight: 0, borderTopLeftRadius: 0 }}
                >
                  {/* Keyed on spec+layer so switching either replays the
                      90ms enter; the AST tree inside is never animated. */}
                  <div className="spec-x-swap" key={`${selected.path}:${layer}`}>
                  {/* source */}
                  {layer === 'source' && (
                    <SpecCodeView
                      lines={sourceSpans}
                      activeLine={hoverLine}
                      onHoverLine={setHoverLine}
                      raw={source}
                      copyLabel={ui.copy}
                      copiedLabel={ui.copied}
                      meta={`${result?.sourceBytes ?? source.length} ${ui.bytes} · ${ui.highlightNote}`}
                    />
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
                    result.hir.ok ? (
                      codeSpans ? (
                        <SpecCodeView
                          lines={codeSpans}
                          raw={result.hir.text || ''}
                          copyLabel={ui.copy}
                          copiedLabel={ui.copied}
                          meta={`${result.hir.text?.length ?? 0} ${ui.bytes} · ${ui.generated}`}
                        />
                      ) : (
                        <div style={{ padding: 14, color: C.muted, fontSize: 13 }}>{ui.noHir}</div>
                      )
                    ) : (
                      <pre style={{ ...preStyle, color: C.bad }}>{`${ui.targetFailed}\n\n${result.hir.error}`}</pre>
                    )
                  )}

                  {/* codegen targets */}
                  {LAYERS.find((l) => l.id === layer)?.kind === 'target' && result && (
                    !activeTarget ? (
                      <div style={{ padding: 14, color: C.muted }}>{ui.emptyOut}</div>
                    ) : !activeTarget.ok ? (
                      <pre style={{ ...preStyle, color: C.bad }}>{`${ui.targetFailed}\n\n${activeTarget.error}`}</pre>
                    ) : codeSpans ? (
                      <SpecCodeView
                        lines={codeSpans}
                        raw={activeTarget.code || ''}
                        copyLabel={ui.copy}
                        copiedLabel={ui.copied}
                        meta={`${activeTarget.bytes ?? 0} ${ui.bytes} · ${ui.generated}`}
                      />
                    ) : (
                      <div style={{ padding: 14, color: C.muted }}>{ui.emptyOut}</div>
                    )
                  )}
                  </div>
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
