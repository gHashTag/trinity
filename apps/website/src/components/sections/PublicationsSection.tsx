"use client";
import { motion } from 'framer-motion';
import { useI18n } from '../../i18n/context';

// Zenodo bundle data with DOIs and key metrics
const PUBLICATIONS = [
  {
    id: 'B001',
    title: 'HSLM-1.95M Ternary Neural Networks',
    metric: 'PPL=125, 19.7× smaller',
    doi: '10.5281/zenodo.19227865',
    url: 'https://doi.org/10.5281/zenodo.19227865'
  },
  {
    id: 'B002',
    title: 'Zero-DSP FPGA Architecture',
    metric: '0% DSP, 2.8W power',
    doi: '10.5281/zenodo.19227867',
    url: 'https://doi.org/10.5281/zenodo.19227867'
  },
  {
    id: 'B003',
    title: 'TRI-27 Instruction Set',
    metric: '98.7% test coverage',
    doi: '10.5281/zenodo.19227869',
    url: 'https://doi.org/10.5281/zenodo.19227869'
  },
  {
    id: 'B004',
    title: 'Queen Lotus Self-Learning',
    metric: '5-phase autonomous cycle',
    doi: '10.5281/zenodo.19227871',
    url: 'https://doi.org/10.5281/zenodo.19227871'
  },
  {
    id: 'B005',
    title: 'Tri Language Specification',
    metric: 'Grammar formally defined',
    doi: '10.5281/zenodo.19227873',
    url: 'https://doi.org/10.5281/zenodo.19227873'
  },
  {
    id: 'B006',
    title: 'GF16 Ternary Format',
    metric: '1.58 bits/trit density',
    doi: '10.5281/zenodo.19227875',
    url: 'https://doi.org/10.5281/zenodo.19227875'
  },
  {
    id: 'B007',
    title: 'VSA Operations',
    metric: '11.5× SIMD speedup',
    doi: '10.5281/zenodo.19227877',
    url: 'https://doi.org/10.5281/zenodo.19227877'
  },
  {
    id: 'PARENT',
    title: 'Trinity S³AI Framework',
    metric: 'All bundles integrated',
    doi: '10.5281/zenodo.19227879',
    url: 'https://doi.org/10.5281/zenodo.19227879'
  }
];

export default function PublicationsSection() {
  const { t: { publications: t } } = useI18n();

  return (
    <section id="publications" aria-labelledby="publications-heading" style={{ position: 'relative' }}>
      <motion.div
        className="fade"
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.6 }}
      >
        <span style={{
          color: 'var(--accent)',
          fontSize: '0.85rem',
          textTransform: 'uppercase',
          letterSpacing: '0.15em',
          fontWeight: 500
        }}>
          {t.badge || 'SCIENTIFIC PUBLICATIONS'}
        </span>

        <h2
          id="publications-heading"
          style={{
            fontSize: 'clamp(1.8rem, 5vw, 2.8rem)',
            fontWeight: 500,
            marginTop: '0.75rem',
            marginBottom: '1rem',
            letterSpacing: '-0.03em'
          }}
          dangerouslySetInnerHTML={{ __html: t.title || 'DOI-Backed Research Results' }}
        />

        <p style={{ fontSize: 'clamp(0.95rem, 2vw, 1.05rem)', maxWidth: '600px' }}>
          {t.subtitle || 'All research published on Zenodo with permanent DOI identifiers.'}
        </p>
      </motion.div>

      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))',
        gap: 'clamp(15px, 3vw, 20px)',
        width: '100%',
        marginTop: '2.5rem'
      }}>
        {PUBLICATIONS.map((pub, index) => (
          <motion.a
            key={pub.id}
            href={pub.url}
            target="_blank"
            rel="noopener noreferrer"
            className="pub-card"
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5, delay: 0.1 * index }}
            whileHover={{ y: -4, transition: { duration: 0.2 } }}
            style={{
              display: 'block',
              padding: '1.5rem',
              background: 'rgba(255, 255, 255, 0.03)',
              border: '1px solid var(--border)',
              borderRadius: '12px',
              textDecoration: 'none',
              color: 'inherit',
              transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)'
            }}
          >
            <div style={{
                display: 'inline-block',
                padding: '0.25rem 0.6rem',
                background: 'rgba(0, 255, 136, 0.15)',
                color: 'var(--accent)',
                borderRadius: '4px',
                fontSize: '0.75rem',
                fontWeight: 600,
                marginBottom: '0.75rem'
              }}>
              {pub.id}
            </div>

            <h3 style={{
              fontSize: 'clamp(1rem, 2vw, 1.15rem)',
              fontWeight: 500,
              marginBottom: '0.5rem',
              lineHeight: 1.3
            }}>
              {pub.title}
            </h3>

            <div style={{
              color: 'var(--muted)',
              fontSize: '0.85rem',
              marginBottom: '0.75rem'
            }}>
              {pub.metric}
            </div>

            <div style={{
              display: 'inline-flex',
              alignItems: 'center',
              fontSize: '0.75rem',
              color: 'rgba(52, 152, 219, 0.9)',
              gap: '0.3rem'
            }}>
              <span style={{ opacity: 0.7 }}>DOI:</span>
              <span style={{ fontFamily: 'monospace' }}>{pub.doi}</span>
            </div>
          </motion.a>
        ))}
      </div>

      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ duration: 0.6, delay: 1.0 }}
        style={{ marginTop: '2rem' }}
      >
        <a
          href="https://github.com/gHashTag/trinity/blob/main/docs/research/TRINITY_S3AI_UNIFIED_FRAMEWORK.md"
          target="_blank"
          rel="noopener noreferrer"
          className="btn secondary"
          style={{ fontSize: '0.9rem' }}
        >
          {t.viewAll || 'View Full Documentation →'}
        </a>
      </motion.div>

    </section>
  );
}
