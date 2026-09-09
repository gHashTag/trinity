// The six figures of the system documentation, drawn from data.
//
// Every figure is inline SVG computed from public/docs/system-docs.json at render
// time: the ladder's heights are the catalog counts, the ring has one mark per
// agent card, the cycle one node per PHASE line of the alphabet, the hierarchy one
// bar per law row of the constitution, the graph one edge per resolved binding, the
// tools map one bubble per owner letter and per repository. There is no static
// image; when a count changes the figure changes, and each carries a caption and
// the data-source line the generator recorded.

import type { CSSProperties } from 'react'
import { C } from '../lib/explorerTheme'
import type { DiagramKind, DocFigures } from '../lib/systemDocs'

const LAYER_COLOR: Record<string, string> = { Archetypal: C.golden, Spiritual: C.blue, Physical: C.accent }

const CAPTIONS: Record<DiagramKind, { en: string; ru: string }> = {
  ladder: { en: 'The five-layer ladder: Specs → Skills → Crons → Agents → Tools, with the count each catalog holds today.', ru: 'Пятислойная лестница: спеки → навыки → расписания → агенты → инструменты, с текущим числом карточек в каждом каталоге.' },
  'agent-ring': { en: 'The 27-letter alphabet as a ring: three nonas, coloured by layer; an outer tick marks a letter with a source-bound skill or tool.', ru: 'Алфавит из 27 букв как кольцо: три ноны, цвет — слой; внешняя метка отмечает букву с привязанным по источнику навыком или инструментом.' },
  'phase-cycle': { en: 'The 6+1 phase cycle of AGENT T as the alphabet draws it; the seventh box (GIT WORKFLOW) closes the loop under the SOUL law.', ru: 'Цикл 6+1 фаз АГЕНТА T, как его рисует алфавит; седьмой блок (GIT WORKFLOW) замыкает петлю по закону SOUL.' },
  'law-hierarchy': { en: 'The law hierarchy of the constitution: a higher law wins a conflict, so L1 sits widest and L7 narrowest.', ru: 'Иерархия законов конституции: при конфликте побеждает старший закон, поэтому L1 самый широкий, L7 самый узкий.' },
  'skills-crons-agents': { en: 'Bindings the catalogs can witness: a cron RUNS a skill, an agent HOLDS a skill or a tool. Cards with no edge are counted, not drawn.', ru: 'Связи, которые каталоги могут засвидетельствовать: расписание запускает навык, агент держит навык или инструмент. Карточки без связей посчитаны, но не нарисованы.' },
  'tools-map': { en: 'The tools family map: tri commands grouped by the owner letter (“–” = no owner yet) and MCP servers by repository; a hollow bubble is an external server.', ru: 'Карта семейств инструментов: команды tri по букве-владельцу («–» — владельца пока нет) и MCP-серверы по репозиторию; пустой кружок — внешний сервер.' },
}

const UI = {
  en: { source: 'Data source', figure: 'Figure', unowned: 'no owner', external: 'external', crons: 'crons', skills: 'skills', agents: 'agents', tools: 'tools', noEdges: 'without a drawn edge', specs: 'specs', chapters: 'docs chapters', tri: 'tri commands', mcp: 'MCP servers', repo: 'repository', priority: 'priority', steps: 'steps' },
  ru: { source: 'Источник данных', figure: 'Рисунок', unowned: 'без владельца', external: 'внешний', crons: 'расписания', skills: 'навыки', agents: 'агенты', tools: 'инструменты', noEdges: 'без нарисованных связей', specs: 'спеки', chapters: 'главы документации', tri: 'команды tri', mcp: 'MCP-серверы', repo: 'репозиторий', priority: 'приоритет', steps: 'шагов' },
}

const mono: CSSProperties = { fontFamily: C.mono }

export function FigureFrame({ n, kind, lang, source, children }: { n: number; kind: DiagramKind; lang: string; source: string; children: React.ReactNode }) {
  const L = lang === 'ru' ? 'ru' : 'en'
  const ui = UI[L]
  return (
    <figure className="sysdocs-figure" style={{ margin: '18px 0', padding: 14, border: `1px solid ${C.border}`, borderRadius: 6, background: C.panel }}>
      <div style={{ overflowX: 'auto' }}>{children}</div>
      <figcaption style={{ marginTop: 10, fontSize: 13, color: C.text, lineHeight: 1.5 }}>
        <b style={{ color: C.golden }}>{ui.figure} {n}.</b> {CAPTIONS[kind][L]}
        <div style={{ ...mono, fontSize: 11, color: C.muted, marginTop: 4 }}>{ui.source}: {source}</div>
      </figcaption>
    </figure>
  )
}

export function LadderFigure({ data, lang }: { data: DocFigures['ladder']; lang: string }) {
  const ui = UI[lang === 'ru' ? 'ru' : 'en']
  const steps = [
    { key: 'specs', label: ui.specs, n: data.counts.specs },
    { key: 'skills', label: ui.skills, n: data.counts.skills },
    { key: 'crons', label: ui.crons, n: data.counts.crons },
    { key: 'agents', label: ui.agents, n: data.counts.agents },
    { key: 'tools', label: ui.tools, n: data.counts.tools },
  ]
  const W = 640, H = 230, base = 190, stepW = 116, x0 = 24
  const max = Math.max(...steps.map((s) => Math.log10(Math.max(1, s.n)) + 1))
  return (
    <svg viewBox={`0 0 ${W} ${H}`} width="100%" role="img" aria-label={CAPTIONS.ladder[lang === 'ru' ? 'ru' : 'en']} style={{ maxWidth: W, display: 'block' }}>
      {steps.map((s, i) => {
        const h = 36 + (i * 22) + ((Math.log10(Math.max(1, s.n)) + 1) / max) * 40
        const x = x0 + i * stepW
        return (
          <g key={s.key}>
            <rect x={x} y={base - h} width={stepW - 10} height={h} fill={i === 0 ? 'rgba(255,215,0,0.16)' : 'rgba(0,255,136,0.10)'} stroke={i === 0 ? C.golden : C.accent} strokeWidth={1} />
            <text x={x + (stepW - 10) / 2} y={base - h - 22} textAnchor="middle" fill={C.text} fontSize={20} fontWeight={700} style={mono}>{s.n}</text>
            <text x={x + (stepW - 10) / 2} y={base - h - 8} textAnchor="middle" fill={C.muted} fontSize={11} style={mono}>{i + 1}. {s.label}</text>
            {i < steps.length - 1 && <text x={x + stepW - 8} y={base - h / 2} textAnchor="middle" fill={C.muted} fontSize={14}>→</text>}
          </g>
        )
      })}
      <line x1={x0} y1={base} x2={x0 + steps.length * stepW - 10} y2={base} stroke={C.borderBright} />
      <text x={x0} y={base + 20} fill={C.muted} fontSize={11} style={mono}>{ui.chapters}: {data.counts.docsChapters}</text>
    </svg>
  )
}

export function AgentRingFigure({ data, lang }: { data: DocFigures['agent-ring']; lang: string }) {
  const W = 420, H = 420, cx = W / 2, cy = H / 2, R = 160
  const n = data.agents.length || 1
  return (
    <svg viewBox={`0 0 ${W} ${H}`} width="100%" role="img" aria-label={CAPTIONS['agent-ring'][lang === 'ru' ? 'ru' : 'en']} style={{ maxWidth: W, display: 'block', margin: '0 auto' }}>
      <circle cx={cx} cy={cy} r={R} fill="none" stroke={C.border} />
      {[0, 1, 2].map((k) => {
        const a = (-Math.PI / 2) + (k * 2 * Math.PI) / 3 - Math.PI / n
        return <line key={k} x1={cx + Math.cos(a) * (R - 26)} y1={cy + Math.sin(a) * (R - 26)} x2={cx + Math.cos(a) * (R + 26)} y2={cy + Math.sin(a) * (R + 26)} stroke={C.borderBright} strokeDasharray="3 3" />
      })}
      {data.agents.map((a, i) => {
        const ang = -Math.PI / 2 + (i * 2 * Math.PI) / n
        const x = cx + Math.cos(ang) * R, y = cy + Math.sin(ang) * R
        const col = LAYER_COLOR[a.layer] ?? C.muted
        const bound = a.skills + a.tools > 0
        return (
          <g key={a.letter}>
            <circle cx={x} cy={y} r={13} fill={C.raised} stroke={col} strokeWidth={bound ? 2 : 1} />
            <text x={x} y={y + 4} textAnchor="middle" fill={col} fontSize={12} fontWeight={700} style={mono}>{a.letter}</text>
            {bound && <circle cx={cx + Math.cos(ang) * (R + 22)} cy={cy + Math.sin(ang) * (R + 22)} r={3} fill={col} />}
            <title>{a.ordinal}. {a.name} — {a.layer}{a.skills ? ` · skills ${a.skills}` : ''}{a.tools ? ` · tools ${a.tools}` : ''}</title>
          </g>
        )
      })}
      <text x={cx} y={cy - 6} textAnchor="middle" fill={C.text} fontSize={34} fontWeight={700} style={mono}>{data.agents.length}</text>
      <text x={cx} y={cy + 16} textAnchor="middle" fill={C.muted} fontSize={11} style={mono}>{Object.entries(data.agents.reduce<Record<string, number>>((m, a) => ((m[a.layer] = (m[a.layer] ?? 0) + 1), m), {})).map(([l, c]) => `${l[0]} ${c}`).join(' · ')}</text>
      {(['Archetypal', 'Spiritual', 'Physical'] as const).map((l, i) => (
        <g key={l}>
          <circle cx={20} cy={H - 40 + i * 14} r={4} fill={LAYER_COLOR[l]} />
          <text x={30} y={H - 36 + i * 14} fill={C.muted} fontSize={10} style={mono}>{l}</text>
        </g>
      ))}
    </svg>
  )
}

export function PhaseCycleFigure({ data, lang }: { data: DocFigures['phase-cycle']; lang: string }) {
  const ui = UI[lang === 'ru' ? 'ru' : 'en']
  const W = 520, H = 380, cx = 210, cy = 190, R = 130
  const inner = data.phases.filter((p) => p.n <= 6)
  const outer = data.phases.filter((p) => p.n > 6)
  const pos = (i: number) => { const a = -Math.PI / 2 + (i * 2 * Math.PI) / Math.max(1, inner.length); return { x: cx + Math.cos(a) * R, y: cy + Math.sin(a) * R } }
  return (
    <svg viewBox={`0 0 ${W} ${H}`} width="100%" role="img" aria-label={CAPTIONS['phase-cycle'][lang === 'ru' ? 'ru' : 'en']} style={{ maxWidth: W, display: 'block', margin: '0 auto' }}>
      <defs><marker id="sysdocs-arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0 0L10 5L0 10z" fill={C.accent} /></marker></defs>
      <circle cx={cx} cy={cy} r={R} fill="none" stroke={C.border} strokeDasharray="4 4" />
      {inner.map((p, i) => {
        const a = pos(i), b = pos((i + 1) % inner.length)
        const mx = (a.x + b.x) / 2, my = (a.y + b.y) / 2
        const dx = mx - cx, dy = my - cy, d = Math.hypot(dx, dy) || 1
        const qx = cx + (dx / d) * (R + 18), qy = cy + (dy / d) * (R + 18)
        return <path key={p.n} d={`M${a.x} ${a.y} Q${qx} ${qy} ${b.x} ${b.y}`} fill="none" stroke={C.accent} strokeWidth={1.2} markerEnd="url(#sysdocs-arrow)" opacity={0.8} />
      })}
      {inner.map((p, i) => {
        const { x, y } = pos(i)
        return (
          <g key={p.n}>
            <rect x={x - 48} y={y - 18} width={96} height={36} rx={4} fill={C.raised} stroke={C.accent} />
            <text x={x} y={y - 3} textAnchor="middle" fill={C.golden} fontSize={10} style={mono}>PHASE {p.n}</text>
            <text x={x} y={y + 11} textAnchor="middle" fill={C.text} fontSize={10} fontWeight={700} style={mono}>{p.name}</text>
            <title>{p.steps} {ui.steps}</title>
          </g>
        )
      })}
      {outer.map((p, k) => {
        const x = 440, y = 90 + k * 60
        const from = pos(inner.length - 1)
        return (
          <g key={p.n}>
            <path d={`M${from.x + 48} ${from.y} L${x - 52} ${y}`} fill="none" stroke={C.golden} strokeWidth={1.2} markerEnd="url(#sysdocs-arrow)" />
            <path d={`M${x} ${y + 18} Q${x} ${cy + R + 40} ${cx} ${cy + R + 34} Q${cx - R - 60} ${cy + R + 20} ${pos(0).x - 40} ${pos(0).y - 4}`} fill="none" stroke={C.golden} strokeWidth={1} strokeDasharray="3 3" markerEnd="url(#sysdocs-arrow)" />
            <rect x={x - 52} y={y - 18} width={104} height={36} rx={4} fill="rgba(255,215,0,0.08)" stroke={C.golden} />
            <text x={x} y={y - 3} textAnchor="middle" fill={C.golden} fontSize={10} style={mono}>PHASE {p.n}</text>
            <text x={x} y={y + 11} textAnchor="middle" fill={C.text} fontSize={10} fontWeight={700} style={mono}>{p.name}</text>
            {p.note && <text x={x} y={y + 32} textAnchor="middle" fill={C.muted} fontSize={9} style={mono}>({p.note})</text>}
          </g>
        )
      })}
      <text x={cx} y={cy + 4} textAnchor="middle" fill={C.muted} fontSize={12} style={mono}>{inner.length}+{outer.length}</text>
    </svg>
  )
}

export function LawHierarchyFigure({ data, lang }: { data: DocFigures['law-hierarchy']; lang: string }) {
  const ui = UI[lang === 'ru' ? 'ru' : 'en']
  const W = 560, rowH = 30, H = data.laws.length * rowH + 44
  const n = data.laws.length || 1
  return (
    <svg viewBox={`0 0 ${W} ${H}`} width="100%" role="img" aria-label={CAPTIONS['law-hierarchy'][lang === 'ru' ? 'ru' : 'en']} style={{ maxWidth: W, display: 'block' }}>
      {data.laws.map((l, i) => {
        const w = 500 - (i * (300 / n))
        const x = (W - w) / 2
        return (
          <g key={l.law}>
            <rect x={x} y={8 + i * rowH} width={w} height={rowH - 6} rx={3} fill={`rgba(255,215,0,${(0.22 - i * 0.025).toFixed(3)})`} stroke={C.golden} strokeOpacity={1 - i * 0.09} />
            <text x={x + 10} y={8 + i * rowH + 17} fill={C.golden} fontSize={12} fontWeight={700} style={mono}>{l.law}</text>
            <text x={x + w / 2 + 10} y={8 + i * rowH + 17} textAnchor="middle" fill={C.text} fontSize={12} style={mono}>{l.name}</text>
            {i > 0 && <text x={x - 12} y={8 + i * rowH + 17} textAnchor="end" fill={C.muted} fontSize={12}>{'>'}</text>}
          </g>
        )
      })}
      <text x={W / 2} y={H - 10} textAnchor="middle" fill={C.muted} fontSize={11} style={mono}>{ui.priority}: {data.priority ?? data.laws.map((l) => l.law).join(' > ')}</text>
    </svg>
  )
}

export function BindingsGraphFigure({ data, lang }: { data: DocFigures['skills-crons-agents']; lang: string }) {
  const ui = UI[lang === 'ru' ? 'ru' : 'en']
  const cols: { key: 'crons' | 'skills' | 'agents' | 'tools'; label: string; total: number }[] = [
    { key: 'crons', label: ui.crons, total: data.counts.crons },
    { key: 'skills', label: ui.skills, total: data.counts.skills },
    { key: 'agents', label: ui.agents, total: data.counts.agents },
    { key: 'tools', label: ui.tools, total: data.counts.tools },
  ]
  const nodes: Record<string, string[]> = { crons: [], skills: [], agents: [], tools: [] }
  const add = (col: string, id: string) => { if (!nodes[col].includes(id)) nodes[col].push(id) }
  for (const e of data.edges) {
    if (e.kind === 'cron-runs-skill') { add('crons', e.from); add('skills', e.to) } else if (e.kind === 'agent-holds-skill') { add('agents', e.from); add('skills', e.to) } else { add('agents', e.from); add('tools', e.to) }
  }
  for (const k of Object.keys(nodes)) nodes[k].sort()
  const rows = Math.max(1, ...Object.values(nodes).map((l) => l.length))
  const W = 620, colW = 150, top = 36, rowH = 26, H = top + rows * rowH + 40
  const xOf = (col: string) => cols.findIndex((c) => c.key === col) * colW + 20
  const yOf = (col: string, id: string) => top + nodes[col].indexOf(id) * rowH + 12
  const short = (id: string) => id.replace(/^t27\//, '').replace(/^tri\//, 'tri ').replace(/^mcp\//, 'mcp ')
  return (
    <svg viewBox={`0 0 ${W} ${H}`} width="100%" role="img" aria-label={CAPTIONS['skills-crons-agents'][lang === 'ru' ? 'ru' : 'en']} style={{ maxWidth: W, display: 'block' }}>
      {cols.map((c) => (
        <g key={c.key}>
          <text x={xOf(c.key)} y={18} fill={C.golden} fontSize={11} fontWeight={700} style={mono}>{c.label.toUpperCase()} · {c.total}</text>
          <text x={xOf(c.key)} y={H - 12} fill={C.muted} fontSize={10} style={mono}>{c.total - nodes[c.key].length} {ui.noEdges}</text>
        </g>
      ))}
      {data.edges.map((e, i) => {
        const [fc, tc] = e.kind === 'cron-runs-skill' ? ['crons', 'skills'] : e.kind === 'agent-holds-skill' ? ['agents', 'skills'] : ['agents', 'tools']
        const x1 = xOf(fc) + (fc === 'agents' && tc === 'skills' ? 0 : 120), y1 = yOf(fc, e.from)
        const x2 = xOf(tc) + (fc === 'agents' && tc === 'skills' ? 120 : 0), y2 = yOf(tc, e.to)
        return <path key={i} d={`M${x1} ${y1} C${(x1 + x2) / 2} ${y1} ${(x1 + x2) / 2} ${y2} ${x2} ${y2}`} fill="none" stroke={e.kind === 'agent-holds-tool' ? C.blue : C.accent} strokeWidth={1.2} opacity={0.85} />
      })}
      {cols.map((c) => nodes[c.key].map((id) => (
        <g key={id}>
          <rect x={xOf(c.key)} y={yOf(c.key, id) - 10} width={120} height={20} rx={3} fill={C.raised} stroke={C.border} />
          <text x={xOf(c.key) + 6} y={yOf(c.key, id) + 4} fill={C.text} fontSize={10} style={mono}>{short(id)}</text>
        </g>
      )))}
    </svg>
  )
}

export function ToolsMapFigure({ data, lang }: { data: DocFigures['tools-map']; lang: string }) {
  const ui = UI[lang === 'ru' ? 'ru' : 'en']
  const owners = Object.entries(data.triByAgent).sort(([a], [b]) => (a === '-' ? 1 : b === '-' ? -1 : a.localeCompare(b)))
  const repos = Object.entries(data.mcpByRepo).sort(([a], [b]) => a.localeCompare(b))
  const ext = new Set(data.external)
  const W = 620, H = 250
  const triTotal = owners.reduce((n, [, l]) => n + l.length, 0)
  const mcpTotal = repos.reduce((n, [, l]) => n + l.length, 0)
  return (
    <svg viewBox={`0 0 ${W} ${H}`} width="100%" role="img" aria-label={CAPTIONS['tools-map'][lang === 'ru' ? 'ru' : 'en']} style={{ maxWidth: W, display: 'block' }}>
      <text x={16} y={20} fill={C.golden} fontSize={11} fontWeight={700} style={mono}>{ui.tri.toUpperCase()} · {triTotal}</text>
      {owners.map(([letter, list], i) => {
        const r = 10 + Math.sqrt(list.length) * 6
        const x = 40 + (i % 6) * 58, y = 60 + Math.floor(i / 6) * 70
        return (
          <g key={letter}>
            <circle cx={x} cy={y} r={r} fill={letter === '-' ? 'rgba(139,148,144,0.15)' : 'rgba(0,255,136,0.12)'} stroke={letter === '-' ? C.muted : C.accent} />
            <text x={x} y={y + 4} textAnchor="middle" fill={letter === '-' ? C.muted : C.text} fontSize={12} fontWeight={700} style={mono}>{letter === '-' ? '–' : letter}</text>
            <text x={x} y={y + r + 12} textAnchor="middle" fill={C.muted} fontSize={10} style={mono}>{list.length}{letter === '-' ? ` ${ui.unowned}` : ''}</text>
            <title>{list.join(', ')}</title>
          </g>
        )
      })}
      <line x1={400} y1={10} x2={400} y2={H - 10} stroke={C.border} />
      <text x={416} y={20} fill={C.golden} fontSize={11} fontWeight={700} style={mono}>{ui.mcp.toUpperCase()} · {mcpTotal}</text>
      {repos.map(([repo, list], i) => (
        <g key={repo}>
          <text x={416} y={48 + i * 90} fill={C.muted} fontSize={10} style={mono}>{ui.repo}: {repo}</text>
          {list.map((id, j) => {
            const x = 428 + (j % 5) * 36, y = 70 + i * 90 + Math.floor(j / 5) * 34
            const isExt = ext.has(id)
            return (
              <g key={id}>
                <circle cx={x} cy={y} r={11} fill={isExt ? 'none' : 'rgba(88,166,255,0.16)'} stroke={C.blue} strokeDasharray={isExt ? '2 2' : undefined} />
                <text x={x} y={y + 3} textAnchor="middle" fill={C.text} fontSize={8} style={mono}>{id.replace(/^mcp\//, '').slice(0, 4)}</text>
                <title>{id}{isExt ? ` (${ui.external})` : ''}</title>
              </g>
            )
          })}
        </g>
      ))}
    </svg>
  )
}

export function DocFigure({ kind, n, figures, lang }: { kind: DiagramKind; n: number; figures: DocFigures; lang: string }) {
  const f = figures[kind]
  if (!f) return null
  const body =
    kind === 'ladder' ? <LadderFigure data={figures.ladder} lang={lang} />
    : kind === 'agent-ring' ? <AgentRingFigure data={figures['agent-ring']} lang={lang} />
    : kind === 'phase-cycle' ? <PhaseCycleFigure data={figures['phase-cycle']} lang={lang} />
    : kind === 'law-hierarchy' ? <LawHierarchyFigure data={figures['law-hierarchy']} lang={lang} />
    : kind === 'skills-crons-agents' ? <BindingsGraphFigure data={figures['skills-crons-agents']} lang={lang} />
    : <ToolsMapFigure data={figures['tools-map']} lang={lang} />
  return <FigureFrame n={n} kind={kind} lang={lang} source={f.source}>{body}</FigureFrame>
}
