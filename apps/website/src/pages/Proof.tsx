"use client";
import { motion } from 'framer-motion'
import Navigation from '../components/Navigation'
import Footer from '../components/Footer'
import QuantumBackground from '../components/QuantumBackground'

const LINKS = {
  github: 'https://github.com/gHashTag',
  arxiv1: 'https://arxiv.org/abs/2606.05017',
  arxiv2: 'https://arxiv.org/abs/2606.09686',
  sampleReport: 'https://github.com/gHashTag/trinity/blob/main/docs/verification/SAMPLE-REPORT.md',
  triNet: 'https://github.com/gHashTag/tri-net',
  t27: 'https://github.com/gHashTag/t27',
}

const RESULTS = [
  {
    metric: '323 MHz · 41.2 GOPS',
    title: 'GF16 4×4 matmul on Artix-7',
    body: 'A matrix multiplier carrying its arithmetic entirely in logic — 0 DSP48 blocks and 0 inferred latches, timing closed on a Xilinx XC7A200T.',
    how: 'Measured on hardware, not estimated from a report.',
  },
  {
    metric: '100% held-out',
    title: 'A neural network that trains itself on the FPGA',
    body: 'Forward pass, gradient and weight update all in RTL, with no host in the loop. A 2-layer ReLU network learns XOR on the chip itself, 4 of 4 correct.',
    how: 'Every node bit-exact from specification through to silicon.',
  },
  {
    metric: 'SKY130',
    title: 'Tape-out through Tiny Tapeout',
    body: 'The same source that runs on the FPGA went to an open ASIC process: GDS produced, gate-level test passed, precheck passed.',
    how: 'The full path from an arXiv paper to a fabricated design.',
  },
  {
    metric: '≈3–5.5×',
    title: 'GF-T against comparable formats',
    body: 'A ternary floating-point format of my own design, benchmarked best-in-class against comparable ternary formats at mid and far range — no regime decode, native ternary exponent.',
    how: 'Published with an independent reference model and test vectors.',
  },
  {
    metric: 'Over the air',
    title: 'tri-net — a full ternary network stack',
    body: '133 formal specifications: GF16 physical layer, BPSK modem on AD9361, ETX mesh routing, AEAD crypto (ChaCha20-Poly1305 / X25519). Text and images carried between physically separate boards.',
    how: 'Device to device on real radios, with no infrastructure in between.',
  },
  {
    metric: '83 formats',
    title: 'A conformance catalogue anyone can check against',
    body: 'Bit-exact test vectors for FP8, BF16, MXFP4 and microscaling formats — a vendor-neutral reference for verifying low-precision arithmetic.',
    how: 'Published openly so the vectors can be used against any implementation.',
  },
]

const METHOD = [
  ['Independent model, not a mirror', 'The reference model is written from the specification, never from the RTL. A testbench derived from the same assumptions as the design will agree with the design even when both are wrong.'],
  ['Per-stage vectors', 'Known-answer vectors at every pipeline stage, so a regression points at the stage that broke instead of at the top level.'],
  ['Hardware replay', 'The same vectors run again on the physical board. Simulation agreement does not prove silicon agreement — synthesis, place-and-route and timing all get a vote.'],
  ['Open toolchain', 'Yosys, nextpnr-xilinx, prjxray, openFPGALoader, iverilog. No proprietary licence stands between a claim here and someone reproducing it.'],
]

export default function Proof() {
  return (
    <main>
      <QuantumBackground />
      <Navigation />

      <section id="proof" style={{ maxWidth: '900px', textAlign: 'left', alignItems: 'stretch' }}>
        <div className="radial-glow" style={{ opacity: 0.2, background: 'radial-gradient(circle at center, rgba(0, 255, 136, 0.08) 0%, transparent 60%)' }} />

        {/* Hero */}
        <motion.div
          className="premium-card"
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7 }}
          style={{ marginBottom: '2rem' }}
        >
          <p style={{ color: 'var(--accent)', letterSpacing: '0.14em', textTransform: 'uppercase', fontSize: '0.75rem', margin: '0 0 0.75rem' }}>
            Evidence
          </p>
          <h1 style={{ fontSize: 'clamp(1.9rem, 5.5vw, 2.8rem)', margin: '0 0 1rem', lineHeight: 1.15 }}>
            Every number here was measured.
          </h1>
          <p style={{ fontSize: 'clamp(0.95rem, 2.5vw, 1.1rem)', lineHeight: 1.65, margin: 0, maxWidth: '62ch' }}>
            Hardware claims are cheap to make and hard to check, so this page collects the results
            behind everything else on this site — what was built, what it measured, and how it was
            verified. Where something is a submission rather than a win, or a prototype rather than
            a product, it says so.
          </p>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.75rem', marginTop: '1.75rem' }}>
            <motion.a href={LINKS.sampleReport} target="_blank" rel="noopener noreferrer" className="btn" whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }} style={{ padding: '12px 28px', fontSize: '0.9rem' }}>
              Read a verification report
            </motion.a>
            <motion.a href={LINKS.github} target="_blank" rel="noopener noreferrer" className="btn secondary" whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }} style={{ padding: '12px 28px', fontSize: '0.9rem' }}>
              See the source
            </motion.a>
          </div>
        </motion.div>

        {/* Results */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ marginBottom: '2rem' }}
        >
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginBottom: '1.25rem' }}>Results</h2>
          <div style={{ display: 'grid', gap: '1rem' }}>
            {RESULTS.map((r) => (
              <div key={r.title} className="premium-card" style={{ padding: '1.6rem' }}>
                <p style={{ fontSize: '1.35rem', fontWeight: 700, color: 'var(--accent)', margin: '0 0 0.4rem', fontVariantNumeric: 'tabular-nums' }}>{r.metric}</p>
                <h3 style={{ fontSize: '1.05rem', margin: '0 0 0.55rem' }}>{r.title}</h3>
                <p style={{ fontSize: '0.93rem', lineHeight: 1.6, margin: '0 0 0.7rem', opacity: 0.9 }}>{r.body}</p>
                <p style={{ fontSize: '0.85rem', lineHeight: 1.55, margin: 0, opacity: 0.75, borderLeft: '2px solid var(--accent)', paddingLeft: '0.85rem' }}>{r.how}</p>
              </div>
            ))}
          </div>
        </motion.div>

        {/* Method */}
        <motion.div
          className="premium-card"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ marginBottom: '2rem' }}
        >
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginTop: 0, marginBottom: '1rem' }}>How any of this is checked</h2>
          <div style={{ display: 'grid', gap: '1.1rem' }}>
            {METHOD.map(([t, b]) => (
              <div key={t}>
                <h3 style={{ fontSize: '1rem', margin: '0 0 0.4rem', color: 'var(--accent)' }}>{t}</h3>
                <p style={{ fontSize: '0.91rem', lineHeight: 1.6, margin: 0, opacity: 0.88 }}>{b}</p>
              </div>
            ))}
          </div>
        </motion.div>

        {/* Honesty */}
        <motion.div
          className="premium-card"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ marginBottom: '2rem' }}
        >
          <h2 style={{ fontSize: 'clamp(1.2rem, 3.5vw, 1.55rem)', marginTop: 0, marginBottom: '0.8rem' }}>What these results are not</h2>
          <ul style={{ margin: 0, paddingLeft: '1.25rem', display: 'grid', gap: '0.65rem' }}>
            <li style={{ fontSize: '0.91rem', lineHeight: 1.6, opacity: 0.88 }}>Competition entries are entries. A DARPA CLARA submission and an OpenAI Parameter Golf entry are exactly that — submitted work, not awarded contracts or won prizes.</li>
            <li style={{ fontSize: '0.91rem', lineHeight: 1.6, opacity: 0.88 }}>Measurements come from one device family, a Xilinx Artix-7. They are not multi-corner characterisation and do not claim to be.</li>
            <li style={{ fontSize: '0.91rem', lineHeight: 1.6, opacity: 0.88 }}>The on-chip training result is a proven primitive at small scale — a real network learning on real silicon, not a production training accelerator.</li>
            <li style={{ fontSize: '0.91rem', lineHeight: 1.6, opacity: 0.88 }}>Anything estimated rather than measured is labelled as estimated, here and in every report I send.</li>
          </ul>
        </motion.div>

        {/* Sources */}
        <motion.div
          className="premium-card"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ textAlign: 'center' }}
        >
          <h2 style={{ fontSize: 'clamp(1.2rem, 3.5vw, 1.6rem)', marginTop: 0 }}>Check it yourself</h2>
          <p style={{ fontSize: '0.95rem', lineHeight: 1.6, opacity: 0.9, maxWidth: '52ch', margin: '0 auto 1.5rem' }}>
            The papers, the source and a full example report are all public. That is the point —
            a claim you cannot verify is just a sentence.
          </p>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.75rem', justifyContent: 'center' }}>
            <a href={LINKS.arxiv1} target="_blank" rel="noopener noreferrer" className="btn secondary" style={{ padding: '10px 22px', fontSize: '0.82rem' }}>arXiv:2606.05017</a>
            <a href={LINKS.arxiv2} target="_blank" rel="noopener noreferrer" className="btn secondary" style={{ padding: '10px 22px', fontSize: '0.82rem' }}>arXiv:2606.09686</a>
            <a href={LINKS.t27} target="_blank" rel="noopener noreferrer" className="btn secondary" style={{ padding: '10px 22px', fontSize: '0.82rem' }}>t27</a>
            <a href={LINKS.triNet} target="_blank" rel="noopener noreferrer" className="btn secondary" style={{ padding: '10px 22px', fontSize: '0.82rem' }}>tri-net</a>
          </div>
        </motion.div>
      </section>

      <Footer />
    </main>
  )
}
