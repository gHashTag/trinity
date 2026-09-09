// System documentation -- the project, the rules of the game for its agents, and
// the system in detail, read from one declared document.
//
// Route #/docs (and #/docs/<chapter>). Every word of prose here is the Markdown
// body a chapter spec under specs/docs/chapters names (English canonical; Russian
// from the bundle specs/i18n/docs-ru.t27 points at), pre-rendered into blocks by
// scripts/docs-from-specs.mjs through the real compiler. Every table is generated
// from the catalogs or a canon document, every figure is inline SVG drawn from
// data, and each carries a caption and its data source. Nothing on this page is
// typed twice: the chapter list, the section list, the counts, the sources and
// their pinned links all come from public/docs/system-docs.json.
//
// `embed` mode (prop, or ?embed=1) drops the site header and the outer chrome so
// the Queen's PROJECT view can frame the page whole.

import { useEffect, useMemo, useState, type CSSProperties } from 'react'
import { useParams } from 'react-router-dom'
import { useI18n } from '../i18n/context'
import { usePageMeta } from '../hooks/usePageMeta'
import { useHashParams } from '../hooks/useHashParams'
import { ExplorerHeader } from '../components/ExplorerHeader'
import { DocFigure } from '../components/SystemDocsFigures'
import { C, panelBox } from '../lib/explorerTheme'
import { bodyFor, loadSystemDocs, localized, resolveChapter, systemDocsHash, type Block, type DiagramKind, type DocChapter, type DocTable, type Run, type SystemDocs as Docs } from '../lib/systemDocs'

// The figures this page knows how to draw, in the order the chapters carry them
// (system.t27 DIAGRAMS). A chapter whose DIAGRAM is not on this list renders its
// prose and table and says the figure is not drawn, rather than crashing.
const FIGURE_KINDS: readonly DiagramKind[] = ['ladder', 'agent-ring', 'phase-cycle', 'law-hierarchy', 'skills-crons-agents', 'tools-map'] as const
const knownFigure = (d: string | null): d is DiagramKind => d !== null && (FIGURE_KINDS as readonly string[]).includes(d)

const UI = {
  en: {
    title: 'System documentation',
    subtitle: 'The project, the rules of the game for its agents, and the system in detail',
    metaTitle: 'System documentation',
    metaDescription: 'The t27 / Trinity system as one declared document: what the project claims and how each claim is tagged, the constitution and the rules its agents follow, the five-layer ladder, the 27-letter alphabet, the Queen cycle, the tools, and how every number on the site is witnessed.',
    note: 'Generated from specs/docs/**.t27; prose from docs/system/*.md',
    back: '← Home',
    contents: 'Contents',
    chapter: 'Chapter',
    inThisChapter: 'In this chapter',
    loading: 'loading the document…',
    failed: 'Could not load the system documentation:',
    sources: 'Sources',
    sourcesNote: 'Files this chapter quotes or is generated from, each pinned at a commit; “vendored” means the bytes are served from this site, “checkout” that they were read from the t27 tree at generation time.',
    spec: 'Chapter spec',
    body: 'English body',
    table: 'Table',
    generatedFrom: 'Generated from',
    rows: 'rows',
    fallback: 'This chapter has no translation yet; the English body is shown (FALLBACK = en).',
    pinned: 'Links pinned at',
    compiler: 'compiler wasm',
    typecheck: 'typecheck ok',
    print: 'Print',
    lang: 'RU',
    prev: '← Previous',
    next: 'Next →',
    document: 'Document',
    chapters: 'chapters',
    sections: 'sections',
    figureUnknown: 'Figure not drawn on this page:',
    truthNote: 'Status tags: [measured] a number produced by a run whose output is in a repository; [declared] stated in a spec or canon document; [specified] a .t27 spec that typechecks, no implementation claimed; [external] cited from outside the two repositories; [not claimed] outside what the project asserts.',
  },
  ru: {
    title: 'Документация системы',
    subtitle: 'Проект, правила игры для агентов и система в деталях',
    metaTitle: 'Документация системы',
    metaDescription: 'Система t27 / Trinity как один объявленный документ: что проект утверждает и как помечено каждое утверждение, конституция и правила для агентов, пятислойная лестница, алфавит из 27 букв, цикл Королевы, инструменты и то, как засвидетельствовано каждое число на сайте.',
    note: 'Порождено из specs/docs/**.t27; проза из docs/system/*.md',
    back: '← На главную',
    contents: 'Содержание',
    chapter: 'Глава',
    inThisChapter: 'В этой главе',
    loading: 'загружаем документ…',
    failed: 'Не удалось загрузить документацию системы:',
    sources: 'Источники',
    sourcesNote: 'Файлы, которые глава цитирует или из которых порождена, каждый закреплён за коммитом; «vendored» — байты отдаются с этого сайта, «checkout» — прочитаны из дерева t27 в момент генерации.',
    spec: 'Спека главы',
    body: 'Английский текст',
    table: 'Таблица',
    generatedFrom: 'Порождена из',
    rows: 'строк',
    fallback: 'У этой главы пока нет перевода; показан английский текст (FALLBACK = en).',
    pinned: 'Ссылки закреплены за',
    compiler: 'wasm компилятора',
    typecheck: 'типизация ок',
    print: 'Печать',
    lang: 'EN',
    prev: '← Предыдущая',
    next: 'Следующая →',
    document: 'Документ',
    chapters: 'глав',
    sections: 'разделов',
    figureUnknown: 'Рисунок на этой странице не строится:',
    truthNote: 'Теги статуса: [measured] — число получено запуском, вывод которого лежит в репозитории; [declared] — записано в спеке или каноническом документе; [specified] — спека .t27 проходит типизацию, реализация не заявлена; [external] — взято извне двух репозиториев со ссылкой; [not claimed] — вне того, что проект утверждает.',
  },
}
type Ui = typeof UI.en

// Column labels of the generated tables, keyed by the column names the generator writes.
const COLS = {
  en: { tag: 'tag', claim: 'claim', sources: 'sources', law: 'law', name: 'name', body: 'body', enforcement: 'enforcement', layer: 'layer', dir: 'directory', count: 'count', typecheckOk: 'typecheck ok', source: 'source', letter: 'letter', ordinal: '#', letterName: 'letter name', domain: 'domain', archetype: 'archetype', register: 'register', skills: 'skills', tools: 'tools', n: 'phase', steps: 'steps', id: 'id', family: 'family', repo: 'repository', items: 'actions / tools', agents: 'agents', witness: 'witness', external: 'external', label: 'what is counted' } as Record<string, string>,
  ru: { tag: 'тег', claim: 'утверждение', sources: 'источники', law: 'закон', name: 'имя', body: 'формулировка', enforcement: 'обеспечение', layer: 'слой', dir: 'каталог', count: 'число', typecheckOk: 'типизация ок', source: 'источник', letter: 'буква', ordinal: '№', letterName: 'имя буквы', domain: 'домен', archetype: 'архетип', register: 'регистр', skills: 'навыки', tools: 'инструменты', n: 'фаза', steps: 'шаги', id: 'id', family: 'семейство', repo: 'репозиторий', items: 'действия / инструменты', agents: 'агенты', witness: 'свидетель', external: 'внешний', label: 'что посчитано' } as Record<string, string>,
}

const TAG_COLOR: Record<string, string> = { measured: C.accent, declared: C.golden, specified: C.blue, external: C.muted, 'not claimed': C.bad }

const PRINT_CSS = `
.sysdocs-root { color: ${C.text}; }
/* index.css styles bare <section>, <p>, <h2> for the landing page (centred,
   60vh, clamp() headings); a document reads down a left edge. */
.sysdocs-root section { display: block; padding: 0; margin: 0; min-height: 0; max-width: none; text-align: left; }
.sysdocs-prose p { color: inherit; max-width: none; margin: 0 0 12px; font-size: 14.5px; }
.sysdocs-prose h1, .sysdocs-prose h2, .sysdocs-prose h3, .sysdocs-prose h4 { letter-spacing: 0; line-height: 1.25; font-weight: 600; text-align: left; }
.sysdocs-prose h2 { font-size: 19px; margin: 26px 0 10px; }
.sysdocs-prose h3 { font-size: 15px; }
.sysdocs-prose ul, .sysdocs-prose ol { text-align: left; }
.sysdocs-prose p, .sysdocs-prose li { line-height: 1.62; }
.sysdocs-prose code { font-family: ${C.mono}; font-size: 0.88em; background: rgba(0,255,136,0.08); padding: 1px 5px; border-radius: 3px; color: #cdfbe3; }
.sysdocs-prose a { color: ${C.blue}; }
.sysdocs-prose blockquote { border-left: 3px solid ${C.golden}; margin: 12px 0; padding: 4px 14px; color: #d9d9d9; }
.sysdocs-prose pre { font-family: ${C.mono}; font-size: 12px; background: ${C.raised}; border: 1px solid ${C.border}; padding: 10px 12px; overflow-x: auto; border-radius: 4px; }
.sysdocs-table { border-collapse: collapse; width: 100%; font-size: 12.5px; }
.sysdocs-table th, .sysdocs-table td { border: 1px solid ${C.border}; padding: 6px 8px; vertical-align: top; text-align: left; }
.sysdocs-table th { color: ${C.golden}; font-weight: 600; background: rgba(255,215,0,0.05); position: sticky; top: 0; }
.sysdocs-toc a { color: ${C.text}; text-decoration: none; display: block; padding: 5px 8px; border-radius: 4px; font-size: 13px; }
.sysdocs-toc a:hover { background: rgba(0,255,136,0.08); }
.sysdocs-toc a.is-current { color: ${C.accent}; background: rgba(0,255,136,0.10); }
.sysdocs-toc a.is-section { font-size: 12px; color: ${C.muted}; padding-left: 22px; }
@media print {
  html, body { background: #fff !important; color: #000 !important; }
  .sysdocs-root, .sysdocs-root * { color: #000 !important; background: transparent !important; box-shadow: none !important; }
  .sysdocs-chrome, .sysdocs-toc, .sysdocs-pager, .sysdocs-actions { display: none !important; }
  .sysdocs-main { overflow: visible !important; height: auto !important; padding: 0 !important; max-width: none !important; }
  .sysdocs-figure svg text { fill: #000 !important; }
  .sysdocs-figure svg [stroke] { stroke: #333 !important; }
  .sysdocs-figure, .sysdocs-table { break-inside: avoid; page-break-inside: avoid; }
  .sysdocs-table th, .sysdocs-table td { border-color: #999 !important; }
  .sysdocs-prose code { border: 1px solid #bbb; }
  h2 { break-after: avoid; }
  a[href^="http"]::after { content: " (" attr(href) ")"; font-size: 0.8em; }
}
`

function RunsView({ runs }: { runs: Run[] }) {
  return (
    <>
      {runs.map((r, i) =>
        r.t === 'code' ? <code key={i}>{r.v}</code>
        : r.t === 'strong' ? <strong key={i}>{r.v}</strong>
        : r.t === 'link' ? <a key={i} href={r.href} target="_blank" rel="noopener noreferrer">{r.v}</a>
        : <span key={i}>{r.v}</span>,
      )}
    </>
  )
}

function BlocksView({ blocks }: { blocks: Block[] }) {
  return (
    <>
      {blocks.map((b, i) => {
        if (b.type === 'p') return <p key={i} style={{ margin: '0 0 12px', fontSize: 14.5 }}><RunsView runs={b.runs} /></p>
        if (b.type === 'quote') return <blockquote key={i}><RunsView runs={b.runs} /></blockquote>
        if (b.type === 'h') return b.level === 3 ? <h3 key={i} id={b.id} style={{ fontSize: 15, color: C.golden, margin: '18px 0 8px' }}>{b.text}</h3> : <h4 key={i} id={b.id} style={{ fontSize: 14, margin: '14px 0 6px' }}>{b.text}</h4>
        if (b.type === 'code') return <pre key={i}>{b.text}</pre>
        const items = b.items.map((runs, j) => <li key={j} style={{ margin: '3px 0', fontSize: 14.5 }}><RunsView runs={runs} /></li>)
        return b.type === 'ol' ? <ol key={i} style={{ margin: '0 0 12px', paddingLeft: 24 }}>{items}</ol> : <ul key={i} style={{ margin: '0 0 12px', paddingLeft: 22 }}>{items}</ul>
      })}
    </>
  )
}

function cell(col: string, v: unknown): React.ReactNode {
  if (v === null || v === undefined) return <span style={{ color: C.muted }}>—</span>
  if (col === 'tag') return <span style={{ fontFamily: C.mono, fontSize: 11, color: TAG_COLOR[String(v)] ?? C.text, border: `1px solid ${TAG_COLOR[String(v)] ?? C.border}`, padding: '1px 6px', borderRadius: 10, whiteSpace: 'nowrap' }}>[{String(v)}]</span>
  if (typeof v === 'boolean') return <span style={{ color: v ? C.accent : C.muted, fontFamily: C.mono }}>{v ? 'yes' : 'no'}</span>
  if (Array.isArray(v)) {
    if (col === 'steps') return <ul style={{ margin: 0, paddingLeft: 16 }}>{v.map((s, i) => <li key={i} style={{ fontSize: 12 }}>{String(s)}</li>)}</ul>
    return v.length ? <span style={{ fontFamily: C.mono, fontSize: 11.5 }}>{v.map(String).join(', ')}</span> : <span style={{ color: C.muted }}>—</span>
  }
  if (typeof v === 'number') return <span style={{ fontFamily: C.mono }}>{v}</span>
  const s = String(v)
  if (/^[\w./:@-]+$/.test(s) && (col === 'id' || col === 'source' || col === 'dir' || col === 'law' || col === 'letter' || col === 'register' || col === 'repo' || col === 'witness' || col === 'family')) return <span style={{ fontFamily: C.mono, fontSize: 12 }}>{s}</span>
  return s
}

function TableView({ table, n, ui, cols }: { table: DocTable; n: number; ui: Ui; cols: Record<string, string> }) {
  return (
    <div className="sysdocs-tablewrap" style={{ margin: '18px 0' }}>
      <div style={{ fontSize: 13, marginBottom: 6 }}>
        <b style={{ color: C.golden }}>{ui.table} {n}.</b>{' '}
        <span style={{ fontFamily: C.mono, color: C.muted, fontSize: 12 }}>{table.kind} · {table.rows.length} {ui.rows}</span>
      </div>
      <div style={{ overflowX: 'auto', maxHeight: 520, overflowY: 'auto', border: `1px solid ${C.border}`, borderRadius: 6 }}>
        <table className="sysdocs-table">
          <thead><tr>{table.columns.map((c) => <th key={c}>{cols[c] ?? c}</th>)}</tr></thead>
          <tbody>{table.rows.map((r, i) => <tr key={i}>{table.columns.map((c) => <td key={c}>{cell(c, r[c])}</td>)}</tr>)}</tbody>
        </table>
      </div>
      <div style={{ fontFamily: C.mono, fontSize: 11, color: C.muted, marginTop: 4 }}>{ui.generatedFrom}: {table.source}{table.note ? ` · ${table.note}` : ''}</div>
    </div>
  )
}

function SourcesView({ chapter, ui }: { chapter: DocChapter; ui: Ui }) {
  return (
    <section style={{ marginTop: 26, paddingTop: 14, borderTop: `1px solid ${C.border}` }}>
      <h3 style={{ fontSize: 13, color: C.golden, margin: '0 0 6px', letterSpacing: '0.06em', textTransform: 'uppercase' }}>{ui.sources}</h3>
      <p style={{ fontSize: 12, color: C.muted, margin: '0 0 8px' }}>{ui.sourcesNote}</p>
      <ul style={{ margin: 0, paddingLeft: 18, fontFamily: C.mono, fontSize: 12 }}>
        <li><a href={chapter.links.spec} target="_blank" rel="noopener noreferrer" style={{ color: C.blue }}>{chapter.specPath}</a> <span style={{ color: C.muted }}>· {ui.spec} · sha256 {chapter.sha256.slice(0, 12)}</span></li>
        <li><a href={chapter.links.body} target="_blank" rel="noopener noreferrer" style={{ color: C.blue }}>{chapter.bodyPath}</a> <span style={{ color: C.muted }}>· {ui.body}{chapter.bodySha256 ? ` · sha256 ${chapter.bodySha256.slice(0, 12)}` : ''}</span></li>
        {chapter.sources.map((s) => (
          <li key={s.path}>
            <a href={s.url} target="_blank" rel="noopener noreferrer" style={{ color: C.blue }}>{s.repo === 'trinity' ? `trinity:${s.rel}` : s.rel}</a>{' '}
            <span style={{ color: s.where === 'missing' ? C.bad : C.muted }}>· {s.kind === 'dir' ? 'dir' : 'file'} · {s.where}{s.sha256 ? ` · sha256 ${s.sha256.slice(0, 12)}` : ''}</span>
          </li>
        ))}
      </ul>
    </section>
  )
}

export default function SystemDocs({ embed = false }: { embed?: boolean }) {
  const { lang, setLang } = useI18n()
  const short = lang === 'ru' ? 'ru' : 'en'
  const ui: Ui = UI[short]
  usePageMeta(ui.metaTitle, ui.metaDescription)
  const params = useHashParams()
  const embedded = embed || params.embedded
  const routeParams = useParams<{ chapter?: string }>()

  const [docs, setDocs] = useState<Docs | null>(null)
  const [err, setErr] = useState<string | null>(null)
  const [stem, setStem] = useState<string | null>(routeParams.chapter ?? params.get('chapter'))
  const [narrow, setNarrow] = useState(() => (typeof window === 'undefined' ? false : window.innerWidth < 980))
  const [phone, setPhone] = useState(() => (typeof window === 'undefined' ? false : window.innerWidth < 760))
  const [tocOpen, setTocOpen] = useState(false)

  useEffect(() => {
    const onResize = () => { setNarrow(window.innerWidth < 980); setPhone(window.innerWidth < 760) }
    onResize()
    window.addEventListener('resize', onResize)
    return () => window.removeEventListener('resize', onResize)
  }, [])

  useEffect(() => {
    let alive = true
    loadSystemDocs()
      .then((d) => { if (alive) setDocs(d) })
      .catch((e) => { if (alive) setErr(String(e instanceof Error ? e.message : e)) })
    return () => { alive = false }
  }, [])

  // The Queen's quick jumps rewrite the frame's hash; follow it without a reload.
  useEffect(() => {
    const onHash = () => {
      const m = /^#\/docs(?:\/([^?#]+))?/.exec(window.location.hash)
      const q = new URLSearchParams(window.location.hash.split('?')[1] ?? '')
      setStem(m?.[1] ?? q.get('chapter'))
    }
    window.addEventListener('hashchange', onHash)
    return () => window.removeEventListener('hashchange', onHash)
  }, [])

  const chapter = useMemo(() => (docs ? resolveChapter(docs, stem) : null), [docs, stem])
  const idx = docs && chapter ? docs.chapters.indexOf(chapter) : -1

  useEffect(() => {
    if (!chapter) return
    const main = document.getElementById('sysdocs-main')
    if (main) main.scrollTop = 0
  }, [chapter])

  const go = (s: string, section?: string) => {
    setStem(s)
    setTocOpen(false)
    params.set(systemDocsHash(s, { embedded }))
    if (section) requestAnimationFrame(() => document.getElementById(`sec-${section}`)?.scrollIntoView({ block: 'start', behavior: 'smooth' }))
  }

  const pageStyle: CSSProperties = {
    minHeight: embedded ? '100%' : '100vh',
    height: embedded ? '100%' : '100vh',
    background: C.bg,
    color: C.text,
    display: 'flex',
    flexDirection: 'column',
    fontFamily: "'Inter', system-ui, -apple-system, 'Segoe UI', sans-serif",
  }

  const provenance = docs ? [{ repo: 'gHashTag/t27', shortCommit: docs.pin.ref.slice(0, 9) }, { repo: 'gHashTag/trinity', shortCommit: docs.pin.trinity.slice(0, 9) }] : undefined

  const toc = docs && chapter && (
    <nav className="sysdocs-toc" aria-label={ui.contents} style={{ ...panelBox(embedded), padding: 10, overflowY: 'auto', minWidth: 0 }}>
      <div style={{ fontSize: 11, color: C.muted, letterSpacing: '0.08em', textTransform: 'uppercase', padding: '2px 8px 8px' }}>{ui.contents} · {docs.chapters.length} {ui.chapters} · {docs.counts.sections} {ui.sections}</div>
      {docs.chapters.map((c, i) => (
        <div key={c.id}>
          <a href={systemDocsHash(c.stem, { embedded })} className={c === chapter ? 'is-current' : ''} onClick={(e) => { e.preventDefault(); go(c.stem) }}>
            <span style={{ fontFamily: C.mono, color: C.muted, fontSize: 11, marginRight: 8 }}>{String(i + 1).padStart(2, '0')}</span>{localized(c.title, short)}
          </a>
          {c === chapter && c.sections.map((s) => (
            <a key={s.id} href={`${systemDocsHash(c.stem, { embedded })}`} className="is-section" onClick={(e) => { e.preventDefault(); go(c.stem, s.id) }}>{localized(s.heading, short)}</a>
          ))}
        </div>
      ))}
      <div style={{ fontFamily: C.mono, fontSize: 10.5, color: C.muted, padding: '12px 8px 4px', lineHeight: 1.6, borderTop: `1px solid ${C.border}`, marginTop: 8 }}>
        {ui.pinned} <a href={docs.document.link} target="_blank" rel="noopener noreferrer" style={{ color: C.blue }}>t27@{docs.pin.ref.slice(0, 7)}</a><br />
        {ui.compiler} {docs.compilerWasmSha256.slice(0, 12)}<br />
        {ui.typecheck} {docs.counts.typecheckOk}/{docs.chapters.length + 1}
      </div>
    </nav>
  )

  const actions = docs && (
    <div className="sysdocs-actions" style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
      <button type="button" onClick={() => setLang(short === 'ru' ? 'en' : 'ru')} style={btn}>{ui.lang}</button>
      {!phone && <button type="button" onClick={() => window.print()} style={btn}>{ui.print}</button>}
    </div>
  )

  return (
    <div className="sysdocs-root" style={pageStyle}>
      <style>{PRINT_CSS}</style>
      {!embedded && (
        <div className="sysdocs-chrome">
          <ExplorerHeader title={ui.title} subtitle={ui.subtitle} back={ui.back} note={ui.note} provenance={provenance} provenanceLabel={ui.pinned} narrow={narrow} phone={phone} />
        </div>
      )}
      {err && <div style={{ padding: 20, color: C.bad, fontFamily: C.mono, fontSize: 13 }}>{ui.failed} {err}</div>}
      {!docs && !err && <div style={{ padding: 20, color: C.muted, fontFamily: C.mono, fontSize: 13 }}>{ui.loading}</div>}
      {docs && chapter && (
        <div style={{ flex: 1, minHeight: 0, display: 'grid', gridTemplateColumns: narrow ? '1fr' : '260px minmax(0, 1fr)', gap: 12, padding: embedded ? 8 : 14 }}>
          {narrow ? (
            <div className="sysdocs-toc" style={{ ...panelBox(embedded), padding: '8px 10px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                <button type="button" onClick={() => setTocOpen((v) => !v)} style={{ ...btn, flex: 1, textAlign: 'left' }} aria-expanded={tocOpen}>
                  ☰ {ui.chapter} {idx + 1}/{docs.chapters.length}: {localized(chapter.title, short)}
                </button>
                {actions}
              </div>
              {tocOpen && <div style={{ marginTop: 8 }}>{toc}</div>}
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10, minHeight: 0 }}>
              {toc}
              {!phone && <div style={{ ...panelBox(embedded), padding: 10 }}>{actions}</div>}
            </div>
          )}
          <main id="sysdocs-main" className="sysdocs-main" style={{ ...panelBox(embedded), overflowY: 'auto', padding: phone ? '14px 14px 40px' : '22px 28px 48px', minWidth: 0 }}>
            <article className="sysdocs-prose" style={{ maxWidth: 860 }}>
              <div style={{ fontFamily: C.mono, fontSize: 11, color: C.muted, letterSpacing: '0.08em', textTransform: 'uppercase' }}>{ui.document} · {localized(docs.document.title, short)}</div>
              <h1 style={{ fontSize: phone ? 22 : 28, color: C.golden, margin: '6px 0 14px', lineHeight: 1.2 }}>
                <span style={{ fontFamily: C.mono, color: C.muted, fontSize: 14, marginRight: 10 }}>{ui.chapter} {chapter.order}</span>{localized(chapter.title, short)}
              </h1>
              {(() => {
                const { body, lang: shown } = bodyFor(chapter, short)
                let figN = 0, tabN = 0
                return (
                  <>
                    {shown !== short && <p style={{ fontSize: 12, color: C.warn, fontFamily: C.mono }}>{ui.fallback}</p>}
                    <BlocksView blocks={body.lead} />
                    {chapter.table?.kind === 'claims' && <p style={{ fontSize: 12, color: C.muted, fontFamily: C.mono, lineHeight: 1.5 }}>{ui.truthNote}</p>}
                    {body.sections.map((s, i) => {
                      const secId = chapter.sections[i]?.id ?? s.id
                      const showFig = chapter.diagram && i === 0
                      const showTab = chapter.table && i === Math.min(1, body.sections.length - 1)
                      return (
                        <section key={secId} id={`sec-${secId}`} style={{ scrollMarginTop: 8 }}>
                          <h2 style={{ fontSize: phone ? 17 : 19, color: C.text, margin: '26px 0 10px', paddingBottom: 6, borderBottom: `1px solid ${C.border}` }}>
                            <span style={{ fontFamily: C.mono, color: C.accent, fontSize: 12, marginRight: 10 }}>{chapter.order}.{i + 1}</span>{s.heading}
                          </h2>
                          <BlocksView blocks={s.blocks} />
                          {showFig && chapter.diagram && (knownFigure(chapter.diagram)
                            ? <DocFigure kind={chapter.diagram} n={++figN} figures={docs.figures} lang={short} />
                            : <p style={{ fontFamily: C.mono, fontSize: 12, color: C.warn }}>{ui.figureUnknown} {chapter.diagram}</p>)}
                          {showTab && chapter.table && <TableView table={chapter.table} n={++tabN} ui={ui} cols={COLS[short]} />}
                        </section>
                      )
                    })}
                  </>
                )
              })()}
              <SourcesView chapter={chapter} ui={ui} />
              <nav className="sysdocs-pager" style={{ display: 'flex', justifyContent: 'space-between', marginTop: 24, gap: 10 }}>
                {idx > 0 ? <a href={systemDocsHash(docs.chapters[idx - 1].stem, { embedded })} onClick={(e) => { e.preventDefault(); go(docs.chapters[idx - 1].stem) }} style={pagerLink}>{ui.prev} {localized(docs.chapters[idx - 1].title, short)}</a> : <span />}
                {idx < docs.chapters.length - 1 ? <a href={systemDocsHash(docs.chapters[idx + 1].stem, { embedded })} onClick={(e) => { e.preventDefault(); go(docs.chapters[idx + 1].stem) }} style={{ ...pagerLink, textAlign: 'right' }}>{localized(docs.chapters[idx + 1].title, short)} {ui.next}</a> : <span />}
              </nav>
            </article>
          </main>
        </div>
      )}
    </div>
  )
}

const btn: CSSProperties = { background: C.raised, color: C.text, border: `1px solid ${C.border}`, borderRadius: 4, padding: '6px 10px', fontSize: 12, cursor: 'pointer', fontFamily: C.mono }
const pagerLink: CSSProperties = { color: C.accent, textDecoration: 'none', fontSize: 13, maxWidth: '48%' }
