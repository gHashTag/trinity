"use client";
import { motion } from 'framer-motion'
import Navigation from '../components/Navigation'
import Footer from '../components/Footer'
import QuantumBackground from '../components/QuantumBackground'

const CONTACT = {
  email: 'admin@t27.dev',
  github: 'https://github.com/gHashTag',
  arxiv1: 'https://arxiv.org/abs/2606.05017',
  arxiv2: 'https://arxiv.org/abs/2606.09686',
  sampleReport: 'https://github.com/gHashTag/trinity/blob/main/docs/verification/SAMPLE-REPORT.md',
}

const PRACTICALS = [
  {
    title: 'Turnaround',
    body: 'A single core is typically back within 3–5 working days. Larger blocks are quoted with a date before any work starts — if a deadline is tight, say so in the first message.',
  },
  {
    title: 'Your RTL stays yours',
    body: 'Sources are used only to produce your report, are never published or reused, and are deleted on request once delivered. Happy to sign your NDA before you send anything.',
  },
  {
    title: 'Payment',
    body: 'Invoice in USD or EUR, or stablecoin — whichever is simpler for you. Payment on delivery of the report; the first module is free, so nothing is owed until you have seen the work.',
  },
  {
    title: 'What I need from you',
    body: 'The RTL or specification, a definition of correct behaviour (reference outputs, an algorithm, or a paper), the target frequency, and any constraints. That is usually enough to start.',
  },
]

const LIMITS = [
  'Device is a Xilinx Artix-7 XC7A200T — designs that exceed it, or need transceivers and hard IP the board does not expose, cannot be measured here.',
  'Encrypted netlists and vendor-encrypted IP cannot go through an open-source flow.',
  'This is functional and timing verification on one device — not full sign-off, DFT, or multi-corner characterisation.',
  'Anything estimated rather than measured is labelled as such. Nothing is reported as measured unless it was measured.',
]

const DELIVERABLES = [
  {
    title: 'Bit-exact conformance',
    body: 'Every node of your datapath checked against an independent reference model with KAT vectors — divergence between spec and RTL surfaces before synthesis, not after tape-out.',
  },
  {
    title: 'Timing & resources',
    body: 'Achieved frequency, slack, LUT/FF/BRAM/DSP usage, and a latch-free check — measured on a live Xilinx Artix-7, not estimated.',
  },
  {
    title: 'Reproducible artefacts',
    body: 'Bitstream, test vectors, logs and the exact open-source toolchain versions, so anyone can re-run the whole flow themselves.',
  },
  {
    title: 'No vendor lock-in',
    body: 'Yosys, nextpnr-xilinx, prjxray, openFPGALoader, iverilog. Nothing in the report depends on a proprietary licence you would need to buy.',
  },
]

const TIERS = [
  { name: 'Single core', price: '$300', body: 'One module or IP core: bit-exact check, timing, resources, report.' },
  { name: 'Block', price: '$800', body: 'A full block with multiple cores, integration checks and a written analysis.' },
  { name: 'Tape-out ready', price: '$2 000', body: 'Full verification pass, latch-free/timing sign-off and a review against your target process.' },
  { name: 'Retainer', price: '$1–3k / mo', body: 'Continuous regression on real hardware for your repository, on every release.' },
]

const PROOF = [
  ['323 MHz · 41.2 GOPS', 'GF16 4×4 matmul on Xilinx Artix-7 — 0 DSP48, 0 latches.'],
  ['100% held-out', 'A neural network that trains itself on the FPGA — bit-exact from spec to silicon.'],
  ['SKY130 silicon', 'Taped out through Tiny Tapeout: GDS, gate-level test and precheck passed.'],
  ['83 formats', 'Published bit-exact conformance vectors for FP8, BF16, MXFP4 and microscaling.'],
]

const STEPS = [
  'You send RTL or a specification, and say what "correct" means for it.',
  'I build an independent reference model and run your design on a live Artix-7.',
  'You get a signed report — measured numbers, vectors, bitstream, and every command needed to reproduce it.',
]

export default function HardwareVerification() {
  return (
    <main>
      <QuantumBackground />
      <Navigation />

      <section id="verification" style={{ maxWidth: '900px', textAlign: 'left', alignItems: 'stretch' }}>
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
            Hardware-verified RTL
          </p>
          <h1 style={{ fontSize: 'clamp(1.9rem, 5.5vw, 2.8rem)', margin: '0 0 1rem', lineHeight: 1.15 }}>
            Not simulated. Measured on live silicon.
          </h1>
          <p style={{ fontSize: 'clamp(0.95rem, 2.5vw, 1.1rem)', lineHeight: 1.65, margin: 0, maxWidth: '62ch' }}>
            Send your RTL. It runs on a real Xilinx Artix-7 and comes back with a signed report:
            bit-exact conformance against an independent model, achieved timing, resource usage,
            and the bitstream — on a fully open-source toolchain, so every number can be reproduced.
          </p>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.75rem', marginTop: '1.75rem' }}>
            <motion.a
              href={`mailto:${CONTACT.email}?subject=Hardware%20verification%20request`}
              className="btn"
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              style={{ padding: '12px 28px', fontSize: '0.9rem' }}
            >
              Request a run
            </motion.a>
            <motion.a
              href={CONTACT.sampleReport}
              target="_blank"
              rel="noopener noreferrer"
              className="btn secondary"
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              style={{ padding: '12px 28px', fontSize: '0.9rem' }}
            >
              Read a sample report
            </motion.a>
          </div>
          <p style={{ fontSize: '0.85rem', opacity: 0.75, marginTop: '1.25rem', marginBottom: 0 }}>
            First module verified free — so you can judge the report before paying for anything.
          </p>
        </motion.div>

        {/* What you get */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ marginBottom: '2rem' }}
        >
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginBottom: '1.25rem' }}>What the report contains</h2>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))', gap: '1rem' }}>
            {DELIVERABLES.map((d) => (
              <div key={d.title} className="premium-card" style={{ padding: '1.5rem' }}>
                <h3 style={{ fontSize: '1.05rem', margin: '0 0 0.6rem', color: 'var(--accent)' }}>{d.title}</h3>
                <p style={{ fontSize: '0.92rem', lineHeight: 1.6, margin: 0, opacity: 0.9 }}>{d.body}</p>
              </div>
            ))}
          </div>
        </motion.div>

        {/* How it works */}
        <motion.div
          className="premium-card"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ marginBottom: '2rem' }}
        >
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginTop: 0, marginBottom: '1.25rem' }}>How it works</h2>
          <ol style={{ margin: 0, paddingLeft: '1.25rem', display: 'grid', gap: '0.85rem' }}>
            {STEPS.map((s) => (
              <li key={s} style={{ fontSize: '0.95rem', lineHeight: 1.6, opacity: 0.92 }}>{s}</li>
            ))}
          </ol>
        </motion.div>

        {/* Pricing */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ marginBottom: '2rem' }}
        >
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginBottom: '1.25rem' }}>Pricing</h2>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '1rem' }}>
            {TIERS.map((t) => (
              <div key={t.name} className="premium-card" style={{ padding: '1.5rem' }}>
                <p style={{ fontSize: '0.78rem', letterSpacing: '0.12em', textTransform: 'uppercase', opacity: 0.7, margin: '0 0 0.4rem' }}>{t.name}</p>
                <p style={{ fontSize: '1.6rem', fontWeight: 700, color: 'var(--accent)', margin: '0 0 0.6rem' }}>{t.price}</p>
                <p style={{ fontSize: '0.9rem', lineHeight: 1.55, margin: 0, opacity: 0.88 }}>{t.body}</p>
              </div>
            ))}
          </div>
        </motion.div>

        {/* Proof */}
        <motion.div
          className="premium-card"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ marginBottom: '2rem' }}
        >
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginTop: 0, marginBottom: '0.75rem' }}>Why trust the numbers</h2>
          <p style={{ fontSize: '0.95rem', lineHeight: 1.65, opacity: 0.9, marginTop: 0 }}>
            This pipeline was built for my own research — a ternary floating-point format taken from
            an arXiv paper all the way to working silicon, verified bit-exact at every step.
          </p>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(230px, 1fr))', gap: '1rem', marginTop: '1.25rem' }}>
            {PROOF.map(([metric, note]) => (
              <div key={metric}>
                <p style={{ fontSize: '1.05rem', fontWeight: 700, color: 'var(--accent)', margin: '0 0 0.35rem' }}>{metric}</p>
                <p style={{ fontSize: '0.88rem', lineHeight: 1.55, margin: 0, opacity: 0.85 }}>{note}</p>
              </div>
            ))}
          </div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.75rem', marginTop: '1.5rem' }}>
            <a href={CONTACT.arxiv1} target="_blank" rel="noopener noreferrer" className="btn secondary" style={{ padding: '9px 20px', fontSize: '0.8rem' }}>
              arXiv:2606.05017
            </a>
            <a href={CONTACT.arxiv2} target="_blank" rel="noopener noreferrer" className="btn secondary" style={{ padding: '9px 20px', fontSize: '0.8rem' }}>
              arXiv:2606.09686
            </a>
          </div>
        </motion.div>

        {/* Practicals */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ marginBottom: '2rem' }}
        >
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginBottom: '1.25rem' }}>Working together</h2>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))', gap: '1rem' }}>
            {PRACTICALS.map((p) => (
              <div key={p.title} className="premium-card" style={{ padding: '1.5rem' }}>
                <h3 style={{ fontSize: '1.05rem', margin: '0 0 0.6rem', color: 'var(--accent)' }}>{p.title}</h3>
                <p style={{ fontSize: '0.92rem', lineHeight: 1.6, margin: 0, opacity: 0.9 }}>{p.body}</p>
              </div>
            ))}
          </div>
        </motion.div>

        {/* Scope & limits */}
        <motion.div
          className="premium-card"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ marginBottom: '2rem' }}
        >
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginTop: 0, marginBottom: '0.75rem' }}>What this is not</h2>
          <p style={{ fontSize: '0.95rem', lineHeight: 1.65, opacity: 0.9, marginTop: 0 }}>
            A verification report is only worth something if its limits are stated as clearly as its results.
          </p>
          <ul style={{ margin: '1rem 0 0', paddingLeft: '1.25rem', display: 'grid', gap: '0.7rem' }}>
            {LIMITS.map((l) => (
              <li key={l} style={{ fontSize: '0.92rem', lineHeight: 1.6, opacity: 0.88 }}>{l}</li>
            ))}
          </ul>
        </motion.div>

        {/* Contact */}
        <motion.div
          className="premium-card"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ textAlign: 'center' }}
        >
          <h2 style={{ fontSize: 'clamp(1.2rem, 3.5vw, 1.6rem)', marginTop: 0 }}>Have a design to verify?</h2>
          <p style={{ fontSize: '0.95rem', lineHeight: 1.6, opacity: 0.9, maxWidth: '52ch', margin: '0 auto 1.5rem' }}>
            Tell me what it does and what correct looks like. If it fits on an Artix-7, it can be measured.
          </p>
          <motion.a
            href={`mailto:${CONTACT.email}?subject=Hardware%20verification%20request`}
            className="btn"
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
            style={{ padding: '12px 30px', fontSize: '0.9rem' }}
          >
            {CONTACT.email}
          </motion.a>
        </motion.div>
      </section>

      <Footer />
    </main>
  )
}
