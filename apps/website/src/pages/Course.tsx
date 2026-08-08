"use client";
import { motion } from 'framer-motion'
import { usePageMeta } from '../hooks/usePageMeta'
import Navigation from '../components/Navigation'
import Footer from '../components/Footer'
import QuantumBackground from '../components/QuantumBackground'

const CONTACT = {
  email: 'admin@t27.dev',
  github: 'https://github.com/gHashTag',
}

const MODULES = [
  { n: '01', title: 'The open flow, from nothing', body: 'Yosys, nextpnr-xilinx, prjxray, openFPGALoader and iverilog installed and proven on macOS arm64 or Linux. Your first bitstream blinking on a real board — with no vendor licence anywhere in the chain.' },
  { n: '02', title: 'Exactly as much Verilog as you need', body: 'Synchronous design, registers versus latches, and why an accidental latch is the classic bug that only shows up on silicon. Your first module and testbench.' },
  { n: '03', title: 'Arithmetic — the foundation of ML in hardware', body: 'Why floating point is expensive, what quantisation really costs, and where ternary and low-precision formats come from. GF-T and the BitNet wave, explained from the inside.' },
  { n: '04', title: 'Bit-exact verification (the heart of the course)', body: 'An independent reference model in Python, KAT vectors per stage, cross-checked through iverilog. Why a testbench written from the same assumptions as the design will happily agree with the bug.' },
  { n: '05', title: 'A matrix multiplier that closes timing', body: 'MAC to array to pipeline. Reading timing reports and fighting for frequency, using a real case: 323 MHz, 41.2 GOPS, zero DSP blocks.' },
  { n: '06', title: 'Neural network inference on the FPGA', body: 'Layers, activations, dataflow and on-chip memory — running on the board, not in a simulator.' },
  { n: '07', title: 'Training on-chip (the capstone)', body: 'Backward pass and SGD in RTL. The network learns XOR on the FPGA itself — 4/4, bit-exact against the reference. Almost nobody has built this by hand.' },
  { n: '08', title: 'Onward to silicon', body: 'The Tiny Tapeout path: preparing a design, what changes between FPGA and ASIC, and where the open-silicon ecosystem stands after the move to IHP.' },
]

const TIERS = [
  { name: 'Self-paced', price: '$149', body: 'Video, code, KAT vector sets, community access.' },
  { name: 'Self-paced + hardware', price: '$249', body: 'Everything above, plus remote runs on my Artix-7 boards — no need to own one.' },
  { name: 'Cohort · 4 weeks', price: '$599', body: 'Live sessions, code review, and your own design taken apart with you.' },
  { name: 'Team workshop', price: 'from $2 000', body: 'Two days with your engineers, built around a problem you actually have.' },
]

const AUDIENCE = [
  ['ML engineers', 'You know the models. Textbooks stop at simulation, so hardware still feels like someone else’s country.'],
  ['Students & researchers', 'No vendor licences, no expensive boards, no gatekeeping — the whole flow here is free and open.'],
  ['Embedded developers', 'Comfortable with microcontrollers, moving into edge AI, and needing RTL that carries ML.'],
  ['Tiny Tapeout participants', 'You want the path from specification to verified RTL to a shuttle, without guessing.'],
]

export default function Course() {
  usePageMeta("FPGA training course", "Eight modules from an empty toolchain to a neural network that trains itself on an FPGA — fully open-source, no Vivado, no vendor licence.")
  return (
    <main>
      <QuantumBackground />
      <Navigation />

      <section id="course" style={{ maxWidth: '900px', textAlign: 'left', alignItems: 'stretch' }}>
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
            Course
          </p>
          <h1 style={{ fontSize: 'clamp(1.9rem, 5.5vw, 2.8rem)', margin: '0 0 1rem', lineHeight: 1.15 }}>
            Train a neural network on an FPGA.
          </h1>
          <p style={{ fontSize: 'clamp(0.95rem, 2.5vw, 1.1rem)', lineHeight: 1.65, margin: 0, maxWidth: '62ch' }}>
            Not inference — <strong>training</strong>, on the chip itself. Eight modules from an empty
            toolchain to a network that learns on real silicon, built entirely on open-source tools.
            No Vivado, no licence, nothing you cannot reproduce yourself.
          </p>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.75rem', marginTop: '1.75rem' }}>
            <motion.a
              href={`mailto:${CONTACT.email}?subject=Course%20—%20reserve%20a%20seat`}
              className="btn"
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              style={{ padding: '12px 28px', fontSize: '0.9rem' }}
            >
              Reserve a seat
            </motion.a>
            <motion.a
              href="#/verification"
              className="btn secondary"
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              style={{ padding: '12px 28px', fontSize: '0.9rem' }}
            >
              See the verification work
            </motion.a>
          </div>
          <p style={{ fontSize: '0.85rem', opacity: 0.75, marginTop: '1.25rem', marginBottom: 0 }}>
            The next cohort runs when enough people are in — say the word and I will hold you a place.
          </p>
        </motion.div>

        {/* Why this exists */}
        <motion.div
          className="premium-card"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ marginBottom: '2rem' }}
        >
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginTop: 0, marginBottom: '0.75rem' }}>Why this course exists</h2>
          <p style={{ fontSize: '0.95rem', lineHeight: 1.65, opacity: 0.9, margin: 0 }}>
            Vendor courses teach you vendor tools. ASIC courses stop at the tape-out. Nobody teaches
            the thing I actually had to prove on hardware: a neural network performing its own
            backward pass on an FPGA, verified bit-exact against an independent model — with a
            toolchain a student can install for free on a laptop.
          </p>
          <p style={{ fontSize: '0.95rem', lineHeight: 1.65, opacity: 0.9, marginBottom: 0 }}>
            I teach it because I built it: a number format of my own from an arXiv paper, through RTL
            at 323 MHz with zero DSP blocks, to a SKY130 tape-out — and I have taught over a thousand
            developers before that.
          </p>
        </motion.div>

        {/* Modules */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ marginBottom: '2rem' }}
        >
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginBottom: '1.25rem' }}>Eight modules</h2>
          <div style={{ display: 'grid', gap: '0.85rem' }}>
            {MODULES.map((m) => (
              <div key={m.n} className="premium-card" style={{ padding: '1.35rem 1.5rem', display: 'flex', gap: '1.25rem', alignItems: 'flex-start' }}>
                <span style={{ color: 'var(--accent)', fontWeight: 700, fontSize: '0.95rem', fontVariantNumeric: 'tabular-nums', opacity: 0.8, paddingTop: '0.15rem' }}>{m.n}</span>
                <div>
                  <h3 style={{ fontSize: '1.02rem', margin: '0 0 0.45rem' }}>{m.title}</h3>
                  <p style={{ fontSize: '0.9rem', lineHeight: 1.6, margin: 0, opacity: 0.88 }}>{m.body}</p>
                </div>
              </div>
            ))}
          </div>
        </motion.div>

        {/* Audience */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ marginBottom: '2rem' }}
        >
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginBottom: '1.25rem' }}>Who it is for</h2>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))', gap: '1rem' }}>
            {AUDIENCE.map(([who, why]) => (
              <div key={who} className="premium-card" style={{ padding: '1.5rem' }}>
                <h3 style={{ fontSize: '1.02rem', margin: '0 0 0.55rem', color: 'var(--accent)' }}>{who}</h3>
                <p style={{ fontSize: '0.9rem', lineHeight: 1.6, margin: 0, opacity: 0.88 }}>{why}</p>
              </div>
            ))}
          </div>
          <p style={{ fontSize: '0.9rem', opacity: 0.8, marginTop: '1.25rem' }}>
            Prerequisites: basic Python and the idea of digital logic. Verilog is taught from zero.
            A board is optional — runs on my hardware are included in two of the tiers.
          </p>
        </motion.div>

        {/* Pricing */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ marginBottom: '2rem' }}
        >
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginBottom: '1.25rem' }}>Formats</h2>
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

        {/* CTA */}
        <motion.div
          className="premium-card"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          style={{ textAlign: 'center' }}
        >
          <h2 style={{ fontSize: 'clamp(1.2rem, 3.5vw, 1.6rem)', marginTop: 0 }}>Want a seat in the next cohort?</h2>
          <p style={{ fontSize: '0.95rem', lineHeight: 1.6, opacity: 0.9, maxWidth: '52ch', margin: '0 auto 1.5rem' }}>
            Tell me where you are starting from and what you want to build. I will tell you honestly
            whether this course is the right thing for you.
          </p>
          <motion.a
            href={`mailto:${CONTACT.email}?subject=Course%20—%20reserve%20a%20seat`}
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
