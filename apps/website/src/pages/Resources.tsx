import Navigation from '../components/Navigation'
import Footer from '../components/Footer'
import {
  papers,
  datasets,
  upstream,
  channels,
  identities,
  discrepancies,
  CORPUS_VERIFIED,
  type Resource,
} from '../data/resources'

const wrap: React.CSSProperties = {
  maxWidth: '900px',
  margin: '0 auto',
  padding: '120px 24px 80px',
}

const dim = 'var(--text-dim, #8a8a8a)'
const border = 'var(--border, #2a2a2a)'
const accent = 'var(--accent, #d4af37)'

const badge = (status: Resource['status']): React.CSSProperties => ({
  display: 'inline-block',
  fontSize: '0.68rem',
  letterSpacing: '0.06em',
  textTransform: 'uppercase',
  padding: '2px 7px',
  borderRadius: '4px',
  border: `1px solid ${status === 'broken' ? '#c0392b' : status === 'live' ? accent : border}`,
  color: status === 'broken' ? '#e06055' : status === 'live' ? accent : dim,
  whiteSpace: 'nowrap',
})

function Table({ title, rows, id }: { title: string; rows: Resource[]; id: string }) {
  return (
    <section id={id} style={{ marginBottom: '3.5em' }}>
      <h2 style={{ fontSize: '1.25rem', marginBottom: '0.9em' }}>{title}</h2>
      <div style={{ overflowX: 'auto' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '0.9rem' }}>
          <thead>
            <tr>
              {['Resource', 'Identifier', 'Checked', 'State'].map((h) => (
                <th
                  key={h}
                  style={{
                    textAlign: 'left',
                    padding: '9px 10px',
                    borderBottom: `1px solid ${accent}`,
                    fontWeight: 600,
                    whiteSpace: 'nowrap',
                  }}
                >
                  {h}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => (
              <tr key={r.href}>
                <td style={{ padding: '11px 10px', borderBottom: `1px solid ${border}` }}>
                  <a href={r.href} target="_blank" rel="noopener noreferrer">
                    {r.title}
                  </a>
                  {r.note && (
                    <div style={{ color: dim, fontSize: '0.82rem', marginTop: '5px', lineHeight: 1.55 }}>
                      {r.note}
                    </div>
                  )}
                </td>
                <td
                  style={{
                    padding: '11px 10px',
                    borderBottom: `1px solid ${border}`,
                    color: dim,
                    fontFamily: 'monospace',
                    fontSize: '0.8rem',
                    whiteSpace: 'nowrap',
                  }}
                >
                  {r.id ?? '—'}
                </td>
                <td
                  style={{
                    padding: '11px 10px',
                    borderBottom: `1px solid ${border}`,
                    color: dim,
                    whiteSpace: 'nowrap',
                  }}
                >
                  {r.verified}
                </td>
                <td style={{ padding: '11px 10px', borderBottom: `1px solid ${border}` }}>
                  <span style={badge(r.status)}>{r.status}</span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  )
}

export default function Resources() {
  const bad = discrepancies()
  return (
    <main>
      <Navigation />
      <div style={wrap}>
        <h1 style={{ marginBottom: '0.3em' }}>Resources</h1>
        <p style={{ color: dim, lineHeight: 1.75, marginBottom: '0.6em' }}>
          The canonical list of every public resource in this corpus — papers, DOIs, upstream
          patches, channels, identities. Anything stated elsewhere (GitHub profile, LinkedIn,
          slide decks) is reconciled against this page, not the other way round.
        </p>
        <p style={{ color: dim, lineHeight: 1.75 }}>
          Each row carries the date it was last checked against the live resource. A row is not
          re-dated unless someone actually re-opened it. Corpus last swept:{' '}
          <strong>{CORPUS_VERIFIED}</strong>.
        </p>

        {bad.length > 0 && (
          <section
            style={{
              border: `1px solid ${border}`,
              borderLeft: '3px solid #c0392b',
              borderRadius: '8px',
              padding: '18px 20px',
              margin: '2.4em 0',
            }}
          >
            <div
              style={{
                color: dim,
                fontSize: '0.8rem',
                letterSpacing: '0.05em',
                textTransform: 'uppercase',
                marginBottom: '10px',
              }}
            >
              Known discrepancies — {bad.length}
            </div>
            <p style={{ marginTop: 0, lineHeight: 1.7, color: dim }}>
              Published here rather than quietly fixed, so that anyone who found the wrong
              version elsewhere can see which one is right.
            </p>
            <ul style={{ margin: 0, paddingLeft: '1.2em', lineHeight: 1.7 }}>
              {bad.map((r) => (
                <li key={r.href} style={{ marginBottom: '0.55em' }}>
                  <a href={r.href} target="_blank" rel="noopener noreferrer">
                    {r.title}
                  </a>
                  {r.note && <span style={{ color: dim }}> — {r.note}</span>}
                </li>
              ))}
            </ul>
          </section>
        )}

        <Table id="papers" title="Papers (arXiv)" rows={papers} />
        <Table id="datasets" title="Datasets & software (Zenodo DOI)" rows={datasets} />
        <Table id="upstream" title="Upstream contributions — openXC7/nextpnr-xilinx" rows={upstream} />
        <Table id="channels" title="Channels" rows={channels} />
        <Table id="identities" title="Identities & contact" rows={identities} />
      </div>
      <Footer />
    </main>
  )
}
