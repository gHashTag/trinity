// Line-numbered, syntax-highlighted code pane with a copy button.
//
// Shared by every code-bearing layer in the spec explorer (source, HIR, and the
// five codegen targets) so they cannot drift apart in behaviour or styling.
//
// Rendering is plain DOM rather than an editor component: the source pane has
// to highlight the line an AST node points at, which is far simpler to do when
// each line is a real element we own.

import { memo, useCallback, useState } from 'react'
import { CLS_COLOR, type Span } from '../lib/highlight'

interface Props {
  lines: Span[][]
  /** 1-based line to highlight, e.g. the line an AST node came from. */
  activeLine?: number | null
  onHoverLine?: (line: number | null) => void
  raw: string
  copyLabel: string
  copiedLabel: string
  /** Rendered above the code, e.g. a byte count. */
  meta?: string
}

const MONO = "'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, monospace"

function SpecCodeViewImpl({ lines, activeLine, onHoverLine, raw, copyLabel, copiedLabel, meta }: Props) {
  const [copied, setCopied] = useState(false)

  const copy = useCallback(() => {
    // clipboard is unavailable on insecure origins; the button simply does
    // nothing visible rather than throwing an unhandled rejection.
    navigator.clipboard?.writeText(raw).then(
      () => {
        setCopied(true)
        window.setTimeout(() => setCopied(false), 1400)
      },
      () => {},
    )
  }, [raw])

  const gutter = String(lines.length).length

  return (
    <div style={{ position: 'relative', minHeight: '100%' }}>
      <div
        style={{
          position: 'sticky',
          top: 0,
          zIndex: 2,
          display: 'flex',
          alignItems: 'center',
          gap: 10,
          padding: '6px 10px',
          background: 'rgba(10,10,10,0.94)',
          backdropFilter: 'blur(6px)',
          borderBottom: '1px solid rgba(255,255,255,0.10)',
          fontSize: 11,
          color: '#888888',
          fontFamily: MONO,
        }}
      >
        {meta && <span>{meta}</span>}
        <button
          onClick={copy}
          style={{
            marginLeft: 'auto',
            background: 'transparent',
            border: '1px solid rgba(255,255,255,0.14)',
            borderRadius: 4,
            color: copied ? '#00FF88' : '#888888',
            padding: '3px 10px',
            cursor: 'pointer',
            fontSize: 11,
            fontFamily: 'inherit',
          }}
        >
          {copied ? copiedLabel : copyLabel}
        </button>
      </div>

      <div style={{ fontFamily: MONO, fontSize: 12.5, lineHeight: 1.65 }}>
        {lines.map((spans, i) => {
          const n = i + 1
          const active = activeLine === n
          return (
            <div
              key={i}
              data-line={n}
              onMouseEnter={onHoverLine ? () => onHoverLine(n) : undefined}
              onMouseLeave={onHoverLine ? () => onHoverLine(null) : undefined}
              style={{
                display: 'flex',
                background: active ? 'rgba(255,215,0,0.14)' : 'transparent',
                borderLeft: `2px solid ${active ? '#FFD700' : 'transparent'}`,
              }}
            >
              <span
                style={{
                  width: gutter * 8 + 20,
                  flexShrink: 0,
                  textAlign: 'right',
                  paddingRight: 12,
                  color: '#6e7681',
                  userSelect: 'none',
                }}
              >
                {n}
              </span>
              <span style={{ whiteSpace: 'pre-wrap', wordBreak: 'break-word', flex: 1, paddingRight: 12 }}>
                {spans.length === 0 || (spans.length === 1 && !spans[0].text) ? (
                  ' '
                ) : (
                  spans.map((s, j) => (
                    <span key={j} style={{ color: CLS_COLOR[s.cls] }}>
                      {s.text}
                    </span>
                  ))
                )}
              </span>
            </div>
          )
        })}
      </div>
    </div>
  )
}

export const SpecCodeView = memo(SpecCodeViewImpl)
