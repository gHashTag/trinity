"use client";
import { motion } from 'framer-motion'
import { usePageMeta } from '../hooks/usePageMeta'
import Navigation from '../components/Navigation'
import Footer from '../components/Footer'
import QuantumBackground from '../components/QuantumBackground'

const CONTACT = {
  email: 'admin@t27.dev',
  github: 'https://github.com/gHashTag',
  arxiv1: 'https://arxiv.org/abs/2606.05017',
  arxiv2: 'https://arxiv.org/abs/2606.09686',
}

const ENQUIRY_BODY = [
  'Hi Dmitrii,',
  '',
  '1) Which core are you interested in:',
  '',
  '2) Target device or process (FPGA family, or ASIC node):',
  '',
  '3) What you need it to do — throughput, precision, area or power budget:',
  '',
  '4) Evaluation or production, and rough volume if production:',
  '',
  'Thanks,',
].join('\n')

const mailto = (subject: string) =>
  `mailto:${CONTACT.email}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(ENQUIRY_BODY)}`

const CORES = [
  {
    name: 'GF-T multiplier',
    tag: 'Ternary arithmetic',
    body: 'The multiplier for GF-T, a ternary floating-point format that benchmarks best-in-class (≈3–5.5× against comparable formats). No regime decode, native ternary exponent.',
    proof: 'Published format (arXiv:2606.05017) with an independent reference model and bit-exact test vectors.',
  },
  {
    name: 'GF16 4×4 matmul',
    tag: 'Matrix engine',
    body: 'A matrix multiplier that carries its arithmetic entirely in logic — leaving the DSP columns free for the rest of your system, and porting cleanly to devices with few or no DSP blocks.',
    proof: '323 MHz · 41.2 GOPS · 0 DSP48 · 0 latches, measured on a Xilinx Artix-7.',
  },
  {
    name: 'BPSK modem',
    tag: 'Radio PHY',
    body: 'A BPSK modem built for software-defined radio (AD9361), part of a full ternary network stack with mesh routing and authenticated encryption.',
    proof: 'Proven device-to-device over the air between physically separate boards — not in simulation.',
  },
  {
    name: 'On-chip training primitives',
    tag: 'Edge ML',
    body: 'Neural primitives that perform their own backward pass on the FPGA: forward, gradient and weight update in RTL, with no host in the loop.',
    proof: '100% held-out accuracy; a 2-layer ReLU network solves XOR on real silicon, bit-exact spec→hardware.',
  },
]

const TERMS = [
  { name: 'Evaluation', price: 'from $500', body: 'Source and test vectors for a single project, so you can measure it in your own flow before committing.' },
  { name: 'Single project', price: 'from $2 500', body: 'Use in one product, with integration support and the verification harness that proves it works.' },
  { name: 'Production / multi-project', price: 'quoted', body: 'Broader rights, negotiated per case — including royalty-based terms where that suits you better.' },
  { name: 'Custom arithmetic', price: 'from $150/h', body: 'A format or datapath designed for your constraints, delivered with the same bit-exact verification.' },
]

const INCLUDED = [
  'Synthesisable RTL, readable rather than obfuscated.',
  'An independent reference model — the thing that lets you prove the core is right, not just believe it.',
  'Bit-exact test vectors per pipeline stage, so a regression tells you which stage broke.',
  'A measured report on real hardware: frequency, resources, latch-free check.',
  'Integration help, because a core that does not land in your system is worth nothing.',
]

export default function Licensing() {
  usePageMeta("Core licensing", "License arithmetic cores that have already been measured on hardware: GF-T multiplier, GF16 matmul at 323 MHz with zero DSP blocks, BPSK modem proven over the air.")
  return (
    <main>
      <QuantumBackground />
      <Navigation />

      <section id="licensing" style={{ maxWidth: '900px' }}>
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
            IP licensing
          </p>
          <h1 style={{ fontSize: 'clamp(1.9rem, 5.5vw, 2.8rem)', margin: '0 0 1rem', lineHeight: 1.15 }}>
            Arithmetic cores that have already been to silicon.
          </h1>
          <p style={{ fontSize: 'clamp(0.95rem, 2.5vw, 1.1rem)', lineHeight: 1.65, margin: 0, maxWidth: '62ch', marginLeft: 'auto', marginRight: 'auto' }}>
            Every core here was designed, verified bit-exact against an independent model, and
            measured on real hardware — one of them through a SKY130 tape-out. You license the
            RTL, the reference model and the vectors that prove it, so you can check the claims
            instead of trusting them.
          </p>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.75rem', marginTop: '1.75rem' }}>
            <motion.a href={mailto('IP licensing enquiry')} className="btn" whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }} style={{ padding: '12px 28px', fontSize: '0.9rem' }}>
              Enquire about a core
            </motion.a>
            <motion.a href="#/verification" className="btn secondary" whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }} style={{ padding: '12px 28px', fontSize: '0.9rem' }}>
              How I verify
            </motion.a>
          </div>
        </motion.div>

        {/* Cores */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ marginBottom: '2rem' }}
        >
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginBottom: '1.25rem' }}>Available cores</h2>
          <div style={{ display: 'grid', gap: '1rem' }}>
            {CORES.map((c) => (
              <div key={c.name} className="premium-card" style={{ padding: '1.6rem' }}>
                <div style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'baseline', gap: '0.75rem', marginBottom: '0.6rem' }}>
                  <h3 style={{ fontSize: '1.1rem', margin: 0 }}>{c.name}</h3>
                  <span style={{ fontSize: '0.7rem', letterSpacing: '0.1em', textTransform: 'uppercase', color: 'var(--accent)', opacity: 0.85 }}>{c.tag}</span>
                </div>
                <p style={{ fontSize: '0.93rem', lineHeight: 1.6, margin: '0 0 0.7rem', opacity: 0.9 }}>{c.body}</p>
                <p style={{ fontSize: '0.85rem', lineHeight: 1.55, margin: 0, opacity: 0.75, borderLeft: '2px solid var(--accent)', paddingLeft: '0.85rem' }}>
                  {c.proof}
                </p>
              </div>
            ))}
          </div>
        </motion.div>

        {/* What you get */}
        <motion.div
          className="premium-card"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ marginBottom: '2rem' }}
        >
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginTop: 0, marginBottom: '1rem' }}>What a licence includes</h2>
          <ul style={{ margin: 0, paddingLeft: '1.25rem', display: 'grid', gap: '0.7rem' }}>
            {INCLUDED.map((i) => (
              <li key={i} style={{ fontSize: '0.93rem', lineHeight: 1.6, opacity: 0.9 }}>{i}</li>
            ))}
          </ul>
        </motion.div>

        {/* Terms */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ marginBottom: '2rem' }}
        >
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginBottom: '1.25rem' }}>Terms</h2>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '1rem' }}>
            {TERMS.map((t) => (
              <div key={t.name} className="premium-card" style={{ padding: '1.5rem' }}>
                <p style={{ fontSize: '0.78rem', letterSpacing: '0.12em', textTransform: 'uppercase', opacity: 0.7, margin: '0 0 0.4rem' }}>{t.name}</p>
                <p style={{ fontSize: '1.4rem', fontWeight: 700, color: 'var(--accent)', margin: '0 0 0.6rem' }}>{t.price}</p>
                <p style={{ fontSize: '0.88rem', lineHeight: 1.55, margin: 0, opacity: 0.88 }}>{t.body}</p>
              </div>
            ))}
          </div>
          <p style={{ fontSize: '0.86rem', opacity: 0.75, marginTop: '1.25rem', lineHeight: 1.6 }}>
            Prices are starting points, not a tariff — the honest number depends on the device, the
            rights you need and how much integration work comes with it. Ask and you get a real
            figure, not a brochure.
          </p>
        </motion.div>

        {/* CTA */}
        <motion.div
          className="premium-card"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ textAlign: 'center' }}
        >
          <h2 style={{ fontSize: 'clamp(1.2rem, 3.5vw, 1.6rem)', marginTop: 0 }}>Which core fits your design?</h2>
          <p style={{ fontSize: '0.95rem', lineHeight: 1.6, opacity: 0.9, maxWidth: '52ch', margin: '0 auto 1rem' }}>
            Tell me the device and the budget you are working against. If none of these cores is
            right, I will say so — and quote for one built to fit.
          </p>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.75rem', justifyContent: 'center', marginBottom: '1.25rem' }}>
            <a href={CONTACT.arxiv1} target="_blank" rel="noopener noreferrer" className="btn secondary" style={{ padding: '9px 20px', fontSize: '0.8rem' }}>arXiv:2606.05017</a>
            <a href={CONTACT.arxiv2} target="_blank" rel="noopener noreferrer" className="btn secondary" style={{ padding: '9px 20px', fontSize: '0.8rem' }}>arXiv:2606.09686</a>
          </div>
          <motion.a href={mailto('IP licensing enquiry')} className="btn" whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }} style={{ padding: '12px 30px', fontSize: '0.9rem' }}>
            {CONTACT.email}
          </motion.a>
        </motion.div>
      </section>

      <Footer />
    </main>
  )
}
