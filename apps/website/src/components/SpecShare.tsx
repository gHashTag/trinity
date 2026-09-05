// Share one spec.
//
// Sharing only means anything if the link reopens what the sharer was looking
// at, so this is built on the `?spec=` deep link rather than the bare /specs
// URL -- a link to "the explorer, go find it yourself" is not a share.
//
// The share text carries the spec's own measured facts (nodes, backends,
// health) instead of a generic blurb, for the same reason the descriptions do:
// numbers that came from the compiler cannot drift from the artifact.

import { useCallback, useState } from 'react'
import type { SpecEntry } from '../lib/t27Compiler'

const MONO = "'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, monospace"

export function specUrl(path: string): string {
  const base = `${window.location.origin}${window.location.pathname}`
  return `${base}#/specs?spec=${encodeURIComponent(path)}`
}

export function SpecShare({
  spec,
  labels,
}: {
  spec: SpecEntry
  labels: { share: string; copy: string; copied: string }
}) {
  const [copied, setCopied] = useState(false)
  const url = specUrl(spec.path)
  const u = encodeURIComponent(url)

  const name = spec.module || spec.name
  const headline = `${name} — a .t27 spec through the real compiler: ${spec.tokens.toLocaleString()} tokens, ${spec.nodes.toLocaleString()} AST nodes, ${Object.values(spec.outBytes).filter((v) => v).length} of 5 backends emitting.`
  const title = encodeURIComponent(headline)
  const tgText = encodeURIComponent(`${headline}\n\n#t27 #FPGA #compilers`)

  const targets = [
    { name: 'X', href: `https://twitter.com/intent/tweet?url=${u}&text=${title}&hashtags=t27` },
    { name: 'Telegram', href: `https://t.me/share/url?url=${u}&text=${tgText}` },
    { name: 'LinkedIn', href: `https://www.linkedin.com/sharing/share-offsite/?url=${u}` },
    { name: 'Hacker News', href: `https://news.ycombinator.com/submitlink?u=${u}&t=${title}` },
    { name: 'Reddit', href: `https://www.reddit.com/submit?url=${u}&title=${title}` },
  ]

  const copy = useCallback(() => {
    navigator.clipboard?.writeText(url).then(
      () => {
        setCopied(true)
        window.setTimeout(() => setCopied(false), 1400)
      },
      () => {},
    )
  }, [url])

  const pill: React.CSSProperties = {
    background: 'transparent',
    border: '1px solid rgba(0,255,136,0.18)',
    borderRadius: 999,
    color: '#8b9490',
    padding: '2px 10px',
    fontSize: 10.5,
    fontFamily: MONO,
    textDecoration: 'none',
    cursor: 'pointer',
    whiteSpace: 'nowrap',
  }

  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 5, flexWrap: 'wrap' }}>
      <span style={{ fontSize: 10, color: '#8b9490', opacity: 0.7, fontFamily: MONO }}>{labels.share}</span>
      {targets.map((s) => (
        <a key={s.name} href={s.href} target="_blank" rel="noopener noreferrer" style={pill}>
          {s.name}
        </a>
      ))}
      <button onClick={copy} style={{ ...pill, color: copied ? '#00FF88' : '#8b9490' }}>
        {copied ? labels.copied : labels.copy}
      </button>
    </div>
  )
}
