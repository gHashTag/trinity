"use client";
import { motion } from 'framer-motion'
import { usePageMeta } from '../hooks/usePageMeta'
import Navigation from '../components/Navigation'
import Footer from '../components/Footer'
import QuantumBackground from '../components/QuantumBackground'
import { useI18n } from '../i18n/context'

// Canonical external links (not translated)
const LINKS = {
  linkedin: 'https://linkedin.com/in/neurocoder',
  github: 'https://github.com/gHashTag',
  arxiv1: 'https://arxiv.org/abs/2606.05017',
  arxiv2: 'https://arxiv.org/abs/2606.09686',
  // Served from the apex repository, so it survives a rebuild of the SPA
  cv: 'https://t27.ai/cv.pdf',
}

const PHOTO = 'https://avatars.githubusercontent.com/u/6774813?v=4'

export default function AboutAuthor() {
  usePageMeta("About the author", "Dmitrii Vasilev — hardware-AI and FPGA/RTL engineer, author of the GF-T ternary number format, from specification through RTL to a board.")
  const { t } = useI18n()
  const a = t.about || {}

  return (
    <main>
      <QuantumBackground />
      <Navigation />

      <section id="about" style={{ maxWidth: '900px', alignItems: 'stretch' }}>
        <div className="radial-glow" style={{ opacity: 0.2, background: 'radial-gradient(circle at center, rgba(0, 255, 136, 0.08) 0%, transparent 60%)' }} />

        {/* Header: photo + name + headline.
            `.premium-card` sets flex-direction: column, so a bare display:flex below
            still stacked the photo above the name and left a void under the buttons.
            The row has to be asked for explicitly; wrap keeps the mobile stack. */}
        <motion.div
          className="premium-card"
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7 }}
          style={{ display: 'flex', flexDirection: 'row', gap: 'clamp(1.5rem, 5vw, 3rem)', alignItems: 'center', flexWrap: 'wrap', justifyContent: 'flex-start', marginBottom: '2rem' }}
        >
          <motion.img
            src={PHOTO}
            alt={a.name || 'Dmitrii Vasilev'}
            initial={{ scale: 0.85, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            transition={{ duration: 0.6, delay: 0.15 }}
            whileHover={{ scale: 1.05 }}
            style={{ width: 'clamp(110px, 18vw, 150px)', height: 'clamp(110px, 18vw, 150px)', borderRadius: '50%', border: '1px solid var(--border)' }}
          />
          <div style={{ flex: '1 1 320px' }}>
            <h1 style={{ fontSize: 'clamp(1.8rem, 5vw, 2.6rem)', margin: '0 0 0.5rem', textAlign: 'left' }}>
              {a.name || 'Dmitrii Vasilev'}
            </h1>
            <p style={{ color: 'var(--accent)', fontSize: 'clamp(0.9rem, 2.5vw, 1.05rem)', fontWeight: 500, lineHeight: 1.5, margin: 0, maxWidth: 'none', textAlign: 'left' }}>
              {a.role || 'Hardware-AI & FPGA/RTL Engineer · Author of the GF-T ternary float format · spec → RTL → FPGA · ML systems & Edge AI'}
            </p>

            {/* CTA links */}
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.75rem', marginTop: '1.5rem' }}>
              <motion.a href={LINKS.linkedin} target="_blank" rel="noopener noreferrer" className="btn" whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }} style={{ padding: '10px 24px', fontSize: '0.85rem' }}>
                {a.links?.linkedin || 'LinkedIn'}
              </motion.a>
              <motion.a href={LINKS.cv} target="_blank" rel="noopener noreferrer" className="btn secondary" whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }} style={{ padding: '10px 24px', fontSize: '0.85rem' }}>
                {a.links?.cv || 'Download CV (PDF)'}
              </motion.a>
              <motion.a href={LINKS.github} target="_blank" rel="noopener noreferrer" className="btn secondary" whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }} style={{ padding: '10px 24px', fontSize: '0.85rem' }}>
                {a.links?.github || 'GitHub'}
              </motion.a>
              <motion.a href={LINKS.arxiv1} target="_blank" rel="noopener noreferrer" className="btn secondary" whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }} style={{ padding: '10px 24px', fontSize: '0.85rem' }}>
                {a.links?.arxiv1 || 'arXiv: GoldenFloat'}
              </motion.a>
              <motion.a href={LINKS.arxiv2} target="_blank" rel="noopener noreferrer" className="btn secondary" whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }} style={{ padding: '10px 24px', fontSize: '0.85rem' }}>
                {a.links?.arxiv2 || 'arXiv: 83-Format Catalog'}
              </motion.a>
            </div>
          </div>
        </motion.div>

        {/* Bio */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
          viewport={{ once: true }}
          style={{ marginBottom: '2.5rem' }}
        >
          <h2 style={{ fontSize: 'clamp(1.3rem, 4vw, 1.6rem)', marginBottom: '1rem', textAlign: 'left' }}>
            {a.bioTitle || 'About'}
          </h2>
          {(a.bio || DEFAULT_BIO).map((para: string, i: number) => (
            <p key={i} style={{ color: 'var(--muted)', margin: '0 0 1rem', maxWidth: 'none', textAlign: 'left' }}>
              {para}
            </p>
          ))}
        </motion.div>

        {/* Key achievements */}
        <motion.div
          className="premium-card"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
          viewport={{ once: true }}
          style={{ marginBottom: '2.5rem' }}
        >
          <h2 style={{ fontSize: 'clamp(1.3rem, 4vw, 1.6rem)', marginBottom: '1.2rem', textAlign: 'left' }}>
            {a.achievementsTitle || 'Key achievements (on hardware, 2026)'}
          </h2>
          <ul style={{ listStyle: 'none', margin: 0, padding: 0 }}>
            {(a.achievements || DEFAULT_ACHIEVEMENTS).map((line: string, i: number) => (
              <motion.li
                key={i}
                initial={{ opacity: 0, x: -20 }}
                whileInView={{ opacity: 1, x: 0 }}
                transition={{ delay: 0.1 + i * 0.08 }}
                viewport={{ once: true }}
                style={{ fontSize: '0.9rem', color: 'var(--muted)', marginBottom: '0.85rem', display: 'flex', gap: '0.6rem', lineHeight: 1.55 }}
              >
                <span style={{ color: 'var(--accent)', flexShrink: 0 }}>◆</span>
                <span>{line}</span>
              </motion.li>
            ))}
          </ul>
        </motion.div>

        {/* Publications */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
          viewport={{ once: true }}
          style={{ marginBottom: '2rem' }}
        >
          <h2 style={{ fontSize: 'clamp(1.3rem, 4vw, 1.6rem)', marginBottom: '1.2rem', textAlign: 'left' }}>
            {a.publicationsTitle || 'Publications'}
          </h2>
          {(a.publications || DEFAULT_PUBLICATIONS).map((pub: { title: string; url: string }, i: number) => (
            <p key={i} style={{ margin: '0 0 0.85rem', maxWidth: 'none', textAlign: 'left', color: 'var(--text)' }}>
              <a href={pub.url} target="_blank" rel="noopener noreferrer" style={{ color: 'var(--accent)', textDecoration: 'none' }}>
                {pub.title}
              </a>
            </p>
          ))}
        </motion.div>
      </section>

      <Footer />
    </main>
  )
}

// English defaults (also the fallback content for locales without an `about` block)
const DEFAULT_BIO = [
  'I build the full stack of efficient AI compute — from the number format and the RTL that runs it to bit-exact verification on a board. I am the author of GF-T, a ternary floating-point format, and of the wider GoldenFloat family (GF-T8/16/32; φ-derived GF4→GF1024), published as a catalog of 83 formats with bit-exact conformance vectors.',
  'I took a novel numeric format from an arXiv paper to a live Xilinx Artix-7 (ALINX AX7203, XC7A200T) on a fully open-source flow — Yosys, nextpnr, prjxray, no vendor tools. A SKY130 design has been submitted for fabrication through Tiny Tapeout; there are no measurements on a die. My work centres on the chain spec → RTL → verification → board, where every RTL node is checked bit-for-bit against an independent Python golden model, catching spec/RTL divergence before synthesis.',
  'Before hardware, I spent 10+ years building and teaching software — AI agents and multi-agent systems, React Native, and Web3. I am open to remote / contract work worldwide (UTC+7) across hardware-AI, FPGA / RTL / verification, ML systems, and edge AI.',
]

const DEFAULT_ACHIEVEMENTS = [
  'On-FPGA neural training — primitives that train on the board itself, with the whole spec → RTL → board path checked bit-for-bit against the golden model.',
  'GF16 4×4 matmul — maps into Xilinx Artix-7 fabric with 0 DSP48 and 0 latches: 32,252 LUTs, or 21,223 with the hard multipliers allowed.',
  'Tiny Tapeout SKY130 — the design has been submitted for fabrication: GDS, gate-level test, and precheck all passing. No measurements on a die yet.',
  'Per-node bit-exact verification — every RTL node checked against an independent Python golden model (iverilog + KAT vectors), catching spec/RTL divergence before synthesis.',
  'tri-net — a full ternary network stack (133 .t27 specs): GF16 PHY, a BPSK modem over AD9361, mesh routing, and AEAD crypto — proven device-to-device over the air.',
]

const DEFAULT_PUBLICATIONS = [
  { title: 'GoldenFloat: A φ-Derived Floating-Point Family (GF4→GF1024) — arXiv:2606.05017', url: LINKS.arxiv1 },
  { title: 'An 83-Format Numeric Catalog with Bit-Exact Conformance Vectors: FP8, BF16, MXFP4 — arXiv:2606.09686', url: LINKS.arxiv2 },
]
