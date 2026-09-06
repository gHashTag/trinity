// The CHIP layer: what a .t27 spec commits to in hardware, drawn and animated.
//
// WHAT THIS IS, precisely, because the distinction matters here more than the
// picture does:
//
// This is derived from what the spec DECLARES -- the bit width of every constant,
// the field layout of every packed struct, the parameter and return widths of
// every function. Those are real hardware facts. hello_world.t27 says it in its
// own comments: "a spec has to say what reaches hardware, not leave it to a
// compiler default", and every field carries its own width for that reason.
//
// This is NOT a placed-and-routed netlist, and it is not synthesis output. The
// .t27 -> Verilog backend currently emits module shells: across the 676-spec
// corpus, 361 produce Verilog that yosys accepts, and every one of them yields
// 0 LUTs and 0 flip-flops -- the 4-8 cells that appear are IBUF/OBUF pads. So
// there is no cell placement to show, and drawing one would be an invention.
//
// What IS drawn is the datapath the declarations force: how many bit lanes each
// value needs, where a struct's fields sit relative to one another, and which
// stage feeds which. A reader learns what their types cost. That is worth
// showing and is true; a fake floorplan would be neither.

import { memo, useMemo, useState } from 'react'
import type { ReactElement } from 'react'
import type { T27Node } from '../lib/t27Compiler'
import { SpecSiliconHistory } from './SpecSiliconHistory'

const C = {
  bg: '#0B0D0C',
  panel: '#11150F',
  wire: '#1d2a20',
  green: '#00FF88',
  gold: '#FFD700',
  dim: '#8b9490',
  ink: '#d7e0d8',
  violet: '#c792ea',
} as const

const MONO = "'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, monospace"

/** Bit width of a t27 scalar type, or null when the type is not a fixed-width one. */
export function widthOf(type: string | undefined): number | null {
  if (!type) return null
  const m = /^[iu](\d+)$/.exec(type.trim())
  if (m) {
    const n = Number(m[1])
    return Number.isFinite(n) && n > 0 && n <= 512 ? n : null
  }
  if (/^bool$/.test(type.trim())) return 1
  // A trit is three states. It does not fit in one bit and the language is built
  // on that, so it is shown as 2 lanes rather than rounded down to 1.
  if (/^trit$/i.test(type.trim())) return 2
  return null
}

export interface ChipConst { name: string; type: string; width: number; value?: string }
export interface ChipField { name: string; type: string; width: number }
export interface ChipStruct { name: string; fields: ChipField[]; total: number }
export interface ChipFn { name: string; params: ChipField[]; ret?: ChipField }

export interface ChipModel {
  module?: string
  consts: ChipConst[]
  structs: ChipStruct[]
  fns: ChipFn[]
  /** Widest single value in the design, for lane scaling. */
  maxWidth: number
  /** Declarations that carry no fixed width, so nothing honest can be drawn for them. */
  unsized: number
}

/** Walk the AST and collect only what has a decidable hardware width. */
export function buildChipModel(ast: T27Node | undefined): ChipModel {
  const model: ChipModel = { consts: [], structs: [], fns: [], maxWidth: 1, unsized: 0 }
  if (!ast) return model

  const visit = (n: T27Node) => {
    const kind = n.kind || ''

    if (kind === 'Module' && n.name && !model.module) model.module = n.name

    if (kind.startsWith('Const') && n.name) {
      const w = widthOf(n.type)
      // A struct constant is a layout, not a scalar -- handled below.
      const isStruct = (n.children || []).some((c) => (c.kind || '').includes('Field'))
      if (isStruct) {
        const fields: ChipField[] = []
        for (const c of n.children || []) {
          const fw = widthOf(c.type)
          const fname = c.field || c.name
          if (fw && fname) fields.push({ name: fname, type: c.type || '', width: fw })
          else if (fname) model.unsized += 1
        }
        if (fields.length) {
          const total = fields.reduce((a, f) => a + f.width, 0)
          model.structs.push({ name: n.name, fields, total })
          model.maxWidth = Math.max(model.maxWidth, total)
        }
      } else if (w) {
        model.consts.push({ name: n.name, type: n.type || '', width: w, value: n.value })
        model.maxWidth = Math.max(model.maxWidth, w)
      } else {
        model.unsized += 1
      }
    }

    if (kind.startsWith('Fn') && n.name) {
      const params: ChipField[] = []
      for (const p of n.params || []) {
        const pw = widthOf(p.type)
        if (pw) params.push({ name: p.name, type: p.type, width: pw })
        else model.unsized += 1
      }
      const rw = widthOf(n.returnType)
      const fn: ChipFn = { name: n.name, params }
      if (rw) fn.ret = { name: 'out', type: n.returnType || '', width: rw }
      if (params.length || fn.ret) {
        model.fns.push(fn)
        model.maxWidth = Math.max(model.maxWidth, ...params.map((p) => p.width), rw || 1)
      }
    }

    for (const c of n.children || []) visit(c)
  }

  visit(ast)
  return model
}

/** One bus, drawn as `width` parallel lanes. */
function Bus({ x, y, w, bits, color, label, delay }: {
  x: number; y: number; w: number; bits: number; color: string; label?: string; delay: number
}) {
  // Above ~16 lanes the individual wires stop being readable and start being
  // texture, so the bus collapses to a band with the count written on it.
  const drawn = Math.min(bits, 16)
  const gap = 3
  const h = drawn * gap
  return (
    <g>
      {Array.from({ length: drawn }, (_, i) => (
        <line
          key={i}
          x1={x} y1={y - h / 2 + i * gap} x2={x + w} y2={y - h / 2 + i * gap}
          stroke={color} strokeWidth={1} opacity={0.5}
        />
      ))}
      {/* The travelling pulse: this is what makes it a clocked datapath rather
          than a static diagram. One pulse per bus, staggered by stage. */}
      <circle r={3} fill={color}>
        <animate attributeName="cx" from={x} to={x + w} dur="1.6s" begin={`${delay}s`}
                 repeatCount="indefinite" />
        <animate attributeName="cy" from={y} to={y} dur="1.6s" begin={`${delay}s`}
                 repeatCount="indefinite" />
        <animate attributeName="opacity" values="0;1;1;0" dur="1.6s" begin={`${delay}s`}
                 repeatCount="indefinite" />
      </circle>
      {label && (
        <text x={x + w / 2} y={y - h / 2 - 6} textAnchor="middle"
              fontSize={9} fill={C.dim} fontFamily={MONO}>
          {label}
        </text>
      )}
      {bits > drawn && (
        <text x={x + w / 2} y={y + h / 2 + 12} textAnchor="middle"
              fontSize={9} fill={C.dim} fontFamily={MONO}>
          {bits} lanes
        </text>
      )}
    </g>
  )
}

interface Props {
  ast?: T27Node
  specPath: string
  /** Rendered verbatim; the caller owns wording and language. */
  copy: {
    title: string
    derived: string
    notSynth: string
    empty: string
    consts: string
    structs: string
    fns: string
    bits: string
    unsized: string
    /** Contains {n}, replaced with the number of rows not drawn. */
    omitted: string
  }
}

function SpecChipViewImpl({ ast, specPath, copy }: Props) {
  const model = useMemo(() => buildChipModel(ast), [ast])
  const [running, setRunning] = useState(true)

  const nothing = !model.consts.length && !model.structs.length && !model.fns.length

  // Layout: one row per drawn element, stacked. Width is fixed; height grows.
  //
  // The row budget is not cosmetic. The SVG scales to the panel width, so a spec
  // with 53 functions would shrink every label past legibility -- a diagram that
  // shows everything and lets you read none of it. Draw a readable prefix and
  // state the remainder in words instead of pretending to have drawn it.
  const rowH = 74
  const MAX_ROWS = 12
  const constRow = model.consts.length ? 1 : 0
  const budget = Math.max(1, MAX_ROWS - constRow)
  const structsShown = model.structs.slice(0, budget)
  const fnsShown = model.fns.slice(0, Math.max(0, budget - structsShown.length))
  const omitted =
    model.structs.length - structsShown.length + (model.fns.length - fnsShown.length)
  const rows = constRow + structsShown.length + fnsShown.length
  const H = Math.max(240, 90 + rows * rowH)
  const W = 720

  let y = 96
  const nodes: ReactElement[] = []
  let stage = 0

  if (model.consts.length) {
    const total = model.consts.reduce((a, c) => a + c.width, 0)
    nodes.push(
      <g key="consts">
        <rect x={40} y={y - 26} width={150} height={52} rx={4}
              fill={C.panel} stroke={C.gold} strokeWidth={1} />
        <text x={115} y={y - 8} textAnchor="middle" fontSize={11} fill={C.gold} fontFamily={MONO}>
          {copy.consts}
        </text>
        <text x={115} y={y + 8} textAnchor="middle" fontSize={10} fill={C.dim} fontFamily={MONO}>
          {model.consts.length} × tie-off
        </text>
        <Bus x={190} y={y} w={120} bits={total} color={C.gold} label={`${total} ${copy.bits}`}
             delay={stage * 0.25} />
        <rect x={310} y={y - 26} width={140} height={52} rx={4}
              fill={C.panel} stroke={C.wire} strokeWidth={1} />
        <text x={380} y={y + 4} textAnchor="middle" fontSize={10} fill={C.ink} fontFamily={MONO}>
          constant ROM
        </text>
      </g>,
    )
    y += rowH
    stage += 1
  }

  for (const s of structsShown) {
    // A packed struct IS a bit layout, so it is drawn as one: fields side by
    // side, each sized to its declared width. This is the most literally
    // hardware-shaped thing a .t27 spec contains.
    const scale = 380 / Math.max(s.total, 1)
    let bx = 190
    nodes.push(
      <g key={`s-${s.name}`}>
        <text x={40} y={y - 18} fontSize={11} fill={C.violet} fontFamily={MONO}>
          {s.name}
        </text>
        <text x={40} y={y + 2} fontSize={10} fill={C.dim} fontFamily={MONO}>
          packed · {s.total} {copy.bits}
        </text>
        {s.fields.map((f) => {
          const w = Math.max(f.width * scale, 26)
          const el = (
            <g key={f.name}>
              <rect x={bx} y={y - 18} width={w - 2} height={36} rx={2}
                    fill={C.panel} stroke={C.violet} strokeWidth={1} opacity={0.9} />
              <text x={bx + w / 2 - 1} y={y - 2} textAnchor="middle" fontSize={9.5}
                    fill={C.ink} fontFamily={MONO}>{f.name}</text>
              <text x={bx + w / 2 - 1} y={y + 12} textAnchor="middle" fontSize={9}
                    fill={C.dim} fontFamily={MONO}>{f.type}</text>
            </g>
          )
          bx += w
          return el
        })}
      </g>,
    )
    y += rowH
    stage += 1
  }

  for (const fn of fnsShown) {
    const inW = fn.params.reduce((a, p) => a + p.width, 0)
    nodes.push(
      <g key={`f-${fn.name}`}>
        {fn.params.length > 0 && (
          <Bus x={40} y={y} w={140} bits={inW} color={C.green}
               label={fn.params.map((p) => p.type).join(' ')} delay={stage * 0.25} />
        )}
        <rect x={180} y={y - 24} width={190} height={48} rx={4}
              fill={C.panel} stroke={C.green} strokeWidth={1.2} />
        <text x={275} y={y - 4} textAnchor="middle" fontSize={11} fill={C.green} fontFamily={MONO}>
          {fn.name}
        </text>
        <text x={275} y={y + 12} textAnchor="middle" fontSize={9} fill={C.dim} fontFamily={MONO}>
          {fn.params.length} in → {fn.ret ? 1 : 0} out
        </text>
        {fn.ret && (
          <Bus x={370} y={y} w={140} bits={fn.ret.width} color={C.green}
               label={fn.ret.type} delay={stage * 0.25 + 0.35} />
        )}
        {fn.ret && (
          <rect x={510} y={y - 12} width={22} height={24} rx={2}
                fill="none" stroke={C.dim} strokeWidth={1} />
        )}
      </g>,
    )
    y += rowH
    stage += 1
  }

  return (
    <div style={{ background: C.bg, minHeight: '100%', padding: '14px 16px 22px' }}>
      <div style={{
        display: 'flex', alignItems: 'baseline', gap: 12, flexWrap: 'wrap',
        borderBottom: `1px solid ${C.wire}`, paddingBottom: 10, marginBottom: 14,
      }}>
        <span style={{ font: `600 12px ${MONO}`, color: C.green, letterSpacing: '.08em' }}>
          {copy.title}
        </span>
        <span style={{ font: `10px ${MONO}`, color: C.dim }}>{specPath}</span>
        <button
          onClick={() => setRunning((r) => !r)}
          style={{
            marginLeft: 'auto', background: 'transparent', color: C.dim, cursor: 'pointer',
            border: `1px solid ${C.wire}`, borderRadius: 4, padding: '3px 10px',
            font: `10px ${MONO}`,
          }}
        >
          {running ? '❙❙' : '▶'}
        </button>
      </div>

      {nothing ? (
        <p style={{ font: `12px ${MONO}`, color: C.dim, lineHeight: 1.7, margin: 0 }}>
          {copy.empty}
        </p>
      ) : (
        <svg viewBox={`0 0 ${W} ${H}`} width="100%" style={{
          maxHeight: '62vh', display: 'block',
          // Pausing genuinely stops the SMIL clock rather than hiding it.
          animationPlayState: running ? 'running' : 'paused',
        }} className={running ? '' : 'chip-paused'}>
          {/* The die. Proportional to the real part this project targets, and
              labelled as context rather than as a placement claim. */}
          <rect x={20} y={20} width={W - 40} height={H - 40} rx={6}
                fill="none" stroke={C.wire} strokeWidth={1} strokeDasharray="4 4" />
          <text x={32} y={40} fontSize={9.5} fill={C.dim} fontFamily={MONO}>
            XC7A200T-2FBG484 · AX7203
          </text>
          {model.module && (
            <text x={W - 32} y={40} fontSize={10} textAnchor="end" fill={C.green} fontFamily={MONO}>
              module {model.module}
            </text>
          )}
          {nodes}
        </svg>
      )}

      <div style={{
        marginTop: 14, paddingTop: 12, borderTop: `1px solid ${C.wire}`,
        font: `10.5px/1.75 ${MONO}`, color: C.dim,
      }}>
        <div>{copy.derived}</div>
        {omitted > 0 && (
          <div style={{ marginTop: 6, color: C.gold }}>
            {copy.omitted.replace('{n}', String(omitted))}
          </div>
        )}
        <div style={{ marginTop: 6, color: '#a87a4a' }}>{copy.notSynth}</div>
        {model.unsized > 0 && (
          <div style={{ marginTop: 6 }}>
            {model.unsized} {copy.unsized}
          </div>
        )}
      </div>

      {/* What the schematic above declares, set against what has actually been
          on the board. Renders a plain "no hardware run" for most specs. */}
      <SpecSiliconHistory specPath={specPath} />

      <style>{`.chip-paused animate { animation-play-state: paused }`}</style>
    </div>
  )
}

export const SpecChipView = memo(SpecChipViewImpl)
