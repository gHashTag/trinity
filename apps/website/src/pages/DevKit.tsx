import { useState } from 'react'
import { clubPrice } from '../data/club'
import { motion } from 'framer-motion'
import { usePageMeta } from '../hooks/usePageMeta'
import Navigation from '../components/Navigation'
import Footer from '../components/Footer'
import QuantumBackground from '../components/QuantumBackground'
import TerminalCast from '../components/TerminalCast'
import { FLOW, LAYERS, flowBefore, flowAfter, savedPerBuild, ceiling, hoursPerYear, WORKING_DAYS, CROWD, FIELD } from '../data/devkit'

/**
 * TRI DEV KIT: the open Xilinx 7-series flow, rewritten layer by layer from t27 specs.
 *
 * A proposal page. Every timing comes from one recorded build (src/data/devkit.ts);
 * prices and revenue are drafts and scenarios and say so on the page.
 */

const CONTACT = { email: 'admin@t27.ai', telegram: 'https://t.me/t27ai_bot?start=devkit' }

/** Prices and kit contents are not confirmed. While true, the page says so above them. */
const DRAFT_TERMS = true

const ROADMAP = [
  { id: 'L0', name: 'Chip database', state: 'partly', body: 'Three t27 specs already hold frame addressing, bit positions and packet words for the 7-series. The rest of prjxray-db (tile grid, routing graph) is still read from its JSON.' },
  { id: 'L1', name: 'Synthesis', state: 'not started', body: 'yosys is mature and large. A spec-driven technology mapper for 7-series primitives is possible, but the whole layer is 11% of a build, so even an instant one gives at most 1.65× on the flow.' },
  { id: 'L2', name: 'Place & route', state: 'not started', body: '60% of a build, and the biggest lever: at 0 s the flow would be 8.75× faster. Also the hardest. The realistic path is upstream work on nextpnr-xilinx (we already send patches there) plus spec-checked timing and routing rules, not a rewrite from zero.' },
  { id: 'L3', name: 'FASM → frames', state: 'done', body: 'bitwalk --fasm, built from the specs. Byte-identical to fasm2frames on 22 of 22 corpus files; 33.9 s → 0.42 s on this build.' },
  { id: 'L4', name: 'Frames → .bit', state: 'done', body: 'bitwalk --write. Byte-identical to xc7frames2bit on 16 of 16 frame files. Not faster: 0.25 s against 0.22 s, a tie.' },
  { id: 'L5', name: 'Loader', state: 'not started', body: 'openocd / openFPGALoader. The SRAM load of this design on the AX7203 took 16.7 s, outside the 116.9 s above.' },
  { id: 'L6', name: 'Board receipts', state: 'done for one design', body: 'tri x7-board receipts: the loaded design answers tagged requests. 403,200 of 403,200 on trinet node 0. One design, one board.' },
]

const OPTIONS = [
  { name: 'Open core', price: 'Free', body: 'The tri CLI, the t27 specs and bitwalk under Apache-2.0. Anyone can check the layer table above on their own machine.' },
  { name: 'Kit', price: '$149–199 (draft)', body: 'An Artix-7 board with the flow preinstalled, a receipts harness and one design that proves itself on first power-up. Sold through Crowd Supply, priced against the campaigns below.', featured: true },
  { name: 'Club', price: clubPrice(false), body: 'The Golden Foundry club: a TRI DEV developer agent on your own GitHub issue, plus remote runs on live boards and conformance receipts for your design.' },
]

function Section({ title, children, narrow }: { title: string; children: React.ReactNode; narrow?: boolean }) {
  return (
    <section className="section">
      <div className={narrow ? 'section-inner narrow' : 'section-inner'}>
        <h2 style={{ marginTop: 0 }}>{title}</h2>
        {children}
      </div>
    </section>
  )
}

const muted = { color: 'var(--muted)', fontSize: '0.92rem', lineHeight: 1.6 } as const
const th = { textAlign: 'left', padding: '0.5rem 0.75rem', borderBottom: '1px solid rgba(255,255,255,0.15)', fontWeight: 600, fontSize: '0.85rem' } as const
const td = { padding: '0.5rem 0.75rem', borderBottom: '1px solid rgba(255,255,255,0.06)', fontSize: '0.9rem', verticalAlign: 'top' } as const
const num = { ...td, textAlign: 'right', fontVariantNumeric: 'tabular-nums' } as const

function LayerTable() {
  return (
    <div style={{ overflowX: 'auto' }}>
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead>
          <tr>
            <th style={th}>Layer</th>
            <th style={th}>openXC7 tool</th>
            <th style={{ ...th, textAlign: 'right' }}>Now</th>
            <th style={{ ...th, textAlign: 'right' }}>Share</th>
            <th style={th}>t27</th>
            <th style={{ ...th, textAlign: 'right' }}>t27</th>
            <th style={th}>Same bytes</th>
          </tr>
        </thead>
        <tbody>
          {LAYERS.map(l => (
            <tr key={l.id}>
              <td style={td}>{`${l.id} ${l.name}`}</td>
              <td style={{ ...td, fontFamily: 'monospace' }}>{l.tool}</td>
              <td style={num}>{`${l.s.toFixed(2)} s`}</td>
              <td style={num}>{`${((100 * l.s) / flowBefore).toFixed(1)} %`}</td>
              <td style={{ ...td, fontFamily: 'monospace', color: l.t27 ? 'var(--accent)' : 'var(--muted)' }}>{l.t27 ? l.t27.tool : 'not yet'}</td>
              <td style={num}>{l.t27 ? `${l.t27.s.toFixed(2)} s` : '–'}</td>
              <td style={td}>{l.t27 ? (l.t27.identical ? 'yes' : 'NO') : '–'}</td>
            </tr>
          ))}
          <tr>
            <td style={{ ...td, fontWeight: 600 }} colSpan={2}>Whole flow</td>
            <td style={{ ...num, fontWeight: 600 }}>{`${flowBefore.toFixed(2)} s`}</td>
            <td style={num} />
            <td style={{ ...td, fontWeight: 600 }}>with L3 + L4 in t27</td>
            <td style={{ ...num, fontWeight: 600, color: 'var(--accent)' }}>{`${flowAfter.toFixed(2)} s`}</td>
            <td style={td}>{`${(flowBefore / flowAfter).toFixed(2)}×`}</td>
          </tr>
        </tbody>
      </table>
    </div>
  )
}

function ShareBars() {
  return (
    <div style={{ marginTop: '1.5rem' }} aria-label="Share of one build per layer">
      {LAYERS.map(l => {
        const pct = (100 * l.s) / flowBefore
        const color = l.t27 ? 'var(--accent)' : pct > 30 ? 'var(--golden)' : 'rgba(255,255,255,0.35)'
        return (
          <div key={l.id} style={{ display: 'grid', gridTemplateColumns: '11rem 1fr 4rem', gap: '0.75rem', alignItems: 'center', margin: '0.35rem 0' }}>
            <span style={{ fontSize: '0.85rem' }}>{`${l.id} ${l.name}`}</span>
            <div style={{ background: 'rgba(255,255,255,0.06)', borderRadius: 4, height: 12 }}>
              <div style={{ width: `${pct}%`, background: color, height: '100%', borderRadius: 4, minWidth: 2 }} />
            </div>
            <span style={{ fontSize: '0.85rem', textAlign: 'right', fontVariantNumeric: 'tabular-nums' }}>{`${pct.toFixed(1)} %`}</span>
          </div>
        )
      })}
    </div>
  )
}

function ImpactCalculator() {
  const [builds, setBuilds] = useState(20)
  const [people, setPeople] = useState(1)
  const now = hoursPerYear(savedPerBuild, builds, people)
  const open = LAYERS.filter(l => !l.t27)
  const field = { background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.2)', borderRadius: 6, color: 'inherit', padding: '0.4rem 0.6rem', width: '6rem', fontSize: '1rem' } as const
  return (
    <div className="premium-card">
      <div style={{ display: 'flex', gap: '1.5rem', flexWrap: 'wrap', alignItems: 'end' }}>
        <label style={{ fontSize: '0.85rem' }}>
          Builds a day
          <br />
          <input type="number" min={1} max={500} value={builds} onChange={e => setBuilds(Math.max(1, Number(e.target.value) || 1))} style={field} />
        </label>
        <label style={{ fontSize: '0.85rem' }}>
          People
          <br />
          <input type="number" min={1} max={10000} value={people} onChange={e => setPeople(Math.max(1, Number(e.target.value) || 1))} style={field} />
        </label>
        <span style={{ ...muted, fontSize: '0.8rem' }}>{`${WORKING_DAYS} working days a year. Both inputs are your assumptions, not measurements.`}</span>
      </div>
      <div style={{ marginTop: '1.25rem' }}>
        <div style={{ fontSize: '2rem', fontWeight: 700, color: 'var(--accent)' }}>{`${now.toFixed(1)} h / year`}</div>
        <div style={muted}>{`of waiting removed today, at the measured ${savedPerBuild.toFixed(1)} s per build (L3 + L4 in t27).`}</div>
      </div>
      <ul style={{ ...muted, margin: '1rem 0 0', paddingLeft: '1.1rem' }}>
        {open.map(l => {
          const c = ceiling(l)
          return (
            <li key={l.id}>
              {`If ${l.id} ${l.name.toLowerCase()} took 0 s: at most ${hoursPerYear(flowAfter - c.flow, builds, people).toFixed(1)} more h / year, flow ${flowBefore.toFixed(1)} s → ${c.flow.toFixed(1)} s (${c.x.toFixed(2)}×). A ceiling, not a result.`}
            </li>
          )
        })}
      </ul>
    </div>
  )
}

export default function DevKit() {
  usePageMeta('TRI DEV KIT', 'The open Xilinx 7-series flow, rewritten layer by layer from t27 specs: measured per-layer times, byte-identical replacements, Amdahl ceilings and a business model proposal.')
  const usd = (n: number) => `$${n.toLocaleString('en-US')}`

  return (
    <>
      <QuantumBackground />
      <Navigation />
      <main>
        <section className="section" style={{ paddingTop: '7rem' }}>
          <div className="section-inner narrow">
            <motion.div initial={{ opacity: 0, y: 24 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.6 }}>
              <div style={{ fontSize: '0.8rem', letterSpacing: '0.25em', textTransform: 'uppercase', color: 'var(--muted)', marginBottom: '0.75rem' }}>
                ▼ Trinity S³AI · proposal
              </div>
              <h1 style={{ fontSize: 'clamp(2.2rem, 7vw, 3.6rem)', lineHeight: 1.1, margin: 0 }}>
                <span style={{ color: 'var(--golden)' }}>TRI DEV KIT</span>
                <br />
                the FPGA flow, layer by layer
              </h1>
              <p style={{ fontSize: '1.05rem', lineHeight: 1.7, color: 'var(--muted)', maxWidth: 640, marginTop: '1.25rem' }}>
                {`An open Xilinx 7-series flow where each layer is either rewritten from t27 specs and byte-compared with the tool it replaces, or marked as not yet. On one real XC7A200T build, the two layers done so far take the flow from ${flowBefore.toFixed(1)} s to ${flowAfter.toFixed(1)} s with an identical bitstream. Place and route is 60% of what is left.`}
              </p>
              <div style={{ display: 'flex', gap: '0.75rem', flexWrap: 'wrap', marginTop: '1.75rem' }}>
                <a className="btn" href={FLOW.share}>Watch the recorded build</a>
                <a className="btn secondary" href="#/blog/the-fpga-flow-layer-by-layer">Read the post</a>
              </div>
            </motion.div>
          </div>
        </section>

        <Section title="One build, measured">
          <p style={muted}>
            {`Design ${FLOW.design}, part ${FLOW.part}, ${FLOW.fasmLines.toLocaleString('en-US')} FASM lines, recorded ${FLOW.recorded} with \`tri devkit flow --build\`. Wall seconds on one laptop at a load of ${FLOW.load}; they move with load, the ratios less so. The t27 times are the best of 3 runs right after the build.`}
          </p>
          <LayerTable />
          <ShareBars />
        </Section>

        <Section title="The recording" narrow>
          <TerminalCast
            src={FLOW.cast}
            share={FLOW.share}
            title="tri devkit · the FPGA flow, layer by layer"
            caption="The build and both commands, as they ran. Every byte printed is real and arrives when it did; the prompt and the typing are staged, and silences over 2 s are shortened, with a note in the title bar while that happens."
          />
        </Section>

        <Section title="What the rest could buy" narrow>
          <p style={muted}>
            Amdahl ceilings: how fast the whole flow would be if one more layer took no time at all. A rewrite cannot beat its ceiling, and most will land well below it.
          </p>
          <ImpactCalculator />
        </Section>

        <Section title="Layer by layer">
          <div style={{ display: 'grid', gap: '1rem', gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))' }}>
            {ROADMAP.map(r => {
              const done = r.state.startsWith('done')
              return (
                <div key={r.id} className="premium-card compact" style={done ? { borderColor: 'var(--accent)' } : undefined}>
                  <div style={{ fontSize: '0.75rem', letterSpacing: '0.15em', textTransform: 'uppercase', color: done ? 'var(--accent)' : 'var(--muted)' }}>{`${r.id} · ${r.state}`}</div>
                  <h3 style={{ margin: '0.35rem 0 0.5rem', fontSize: '1.05rem' }}>{r.name}</h3>
                  <p style={{ ...muted, margin: 0 }}>{r.body}</p>
                </div>
              )
            })}
          </div>
        </Section>

        <Section title="Business model, three parts">
          {DRAFT_TERMS ? (
            <p style={{ color: 'var(--golden)', fontSize: '0.85rem', marginTop: 0 }}>Prices are drafts for discussion. Nothing is on sale yet.</p>
          ) : null}
          <div style={{ display: 'grid', gap: '1rem', gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))' }}>
            {OPTIONS.map(o => (
              <div key={o.name} className="premium-card" style={o.featured ? { borderColor: 'var(--accent)' } : undefined}>
                <div style={{ fontSize: '0.75rem', letterSpacing: '0.2em', textTransform: 'uppercase', color: 'var(--muted)' }}>{o.name}</div>
                <div style={{ fontSize: '1.6rem', fontWeight: 700, margin: '0.5rem 0 0.75rem' }}>{o.price}</div>
                <p style={{ ...muted, margin: 0 }}>{o.body}</p>
              </div>
            ))}
          </div>
        </Section>

        <Section title="What open FPGA kits have raised">
          <p style={muted}>Three finished Crowd Supply campaigns, read from their pages on 2026-10-03. They show the size of the audience, not what this kit would raise.</p>
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead>
                <tr>
                  <th style={th}>Campaign</th>
                  <th style={{ ...th, textAlign: 'right' }}>Raised</th>
                  <th style={{ ...th, textAlign: 'right' }}>Backers</th>
                  <th style={{ ...th, textAlign: 'right' }}>Goal</th>
                  <th style={th}>Price</th>
                  <th style={{ ...th, textAlign: 'right' }}>At $179, gross</th>
                </tr>
              </thead>
              <tbody>
                {CROWD.map(c => (
                  <tr key={c.name}>
                    <td style={td}><a href={c.href}>{c.name}</a>{` · ${c.by}`}</td>
                    <td style={num}>{usd(c.raised)}</td>
                    <td style={num}>{c.backers.toLocaleString('en-US')}</td>
                    <td style={num}>{usd(c.goal)}</td>
                    <td style={td}>{c.price}</td>
                    <td style={num}>{usd(c.backers * 179)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p style={{ ...muted, fontSize: '0.82rem' }}>
            The last column is a scenario, not a forecast: the same number of backers at a draft $179, before the platform fee, manufacturing and shipping. All three campaigns had a known board and community before launch; this kit has neither yet.
          </p>
        </Section>

        <Section title="Who else works on this">
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead>
                <tr>
                  <th style={th}>Project</th>
                  <th style={{ ...th, textAlign: 'right' }}>Stars</th>
                  <th style={th}>Relation to this kit</th>
                </tr>
              </thead>
              <tbody>
                {FIELD.map(f => (
                  <tr key={f.name}>
                    <td style={td}><a href={f.href}>{f.name}</a></td>
                    <td style={num}>{f.stars === null ? '–' : f.stars.toLocaleString('en-US')}</td>
                    <td style={{ ...td, color: 'var(--muted)' }}>{f.what}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p style={{ ...muted, fontSize: '0.82rem' }}>Stars read through the GitHub API on 2026-10-03. gHashTag/t27, where the specs live, has 1.</p>
        </Section>

        <Section title="What this page does not claim" narrow>
          <div className="premium-card">
            <ul style={{ margin: 0, paddingLeft: '1.1rem', color: 'var(--muted)', lineHeight: 1.7, fontSize: '0.95rem' }}>
              <li>One design, one laptop, one board. The 1.40× is for this build, not for every design.</li>
              <li>L1 and L2 are not rewritten. Their numbers are ceilings, not results.</li>
              <li>The t27 bitstream is identical to openXC7&apos;s, so it is equivalent, not better.</li>
              <li>The hours a year come from your inputs. The kit and its prices are proposals.</li>
              <li>
                <code>tri devkit</code> and bitwalk are not in a <code>tri</code> release yet, so you cannot install them today. That is tracked in{' '}
                <a href="https://github.com/gHashTag/trinity/issues/1272">trinity#1272</a>.
              </li>
            </ul>
          </div>
          <p style={{ textAlign: 'center', marginTop: '2rem', display: 'flex', gap: '1rem', justifyContent: 'center', flexWrap: 'wrap' }}>
            <a className="btn" href={CONTACT.telegram}>Talk to us</a>
            <a href={`mailto:${CONTACT.email}`} style={{ color: 'var(--muted)', fontSize: '0.9rem', alignSelf: 'center' }}>{CONTACT.email}</a>
          </p>
        </Section>
      </main>
      <Footer />
    </>
  )
}
