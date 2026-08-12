"use client";
import { motion } from 'framer-motion';
import { useI18n } from '../../i18n/context';

// Zenodo bundle data with DOIs and key metrics.
// The metric line used to be a bare English string, so the Russian page showed
// eight English captions among Russian text. Each one is now a pair; languages
// without a translation fall back to English rather than to a missing key.
const PUBLICATIONS = [
  {
    id: 'B001',
    title: 'HSLM-1.95M Ternary Neural Networks',
    metric: { en: 'PPL=125, 19.7× smaller', ru: 'PPL=125, в 19.7× меньше' },
    doi: '10.5281/zenodo.19227865',
    url: 'https://doi.org/10.5281/zenodo.19227865'
  },
  {
    id: 'B002',
    title: 'Zero-DSP FPGA Architecture',
    metric: { en: '0% DSP, 2.8W power', ru: '0% DSP, 2.8 Вт' },
    doi: '10.5281/zenodo.19227867',
    url: 'https://doi.org/10.5281/zenodo.19227867'
  },
  {
    id: 'B003',
    title: 'TRI-27 Instruction Set',
    metric: { en: '98.7% test coverage', ru: '98.7% покрытия тестами' },
    doi: '10.5281/zenodo.19227869',
    url: 'https://doi.org/10.5281/zenodo.19227869'
  },
  {
    id: 'B004',
    title: 'Queen Lotus Self-Learning',
    metric: { en: '5-phase autonomous cycle', ru: 'автономный цикл из 5 фаз' },
    doi: '10.5281/zenodo.19227871',
    url: 'https://doi.org/10.5281/zenodo.19227871'
  },
  {
    id: 'B005',
    title: 'Tri Language Specification',
    metric: { en: 'Grammar formally defined', ru: 'грамматика формально задана' },
    doi: '10.5281/zenodo.19227873',
    url: 'https://doi.org/10.5281/zenodo.19227873'
  },
  {
    id: 'B006',
    title: 'GF16 Ternary Format',
    metric: { en: '1.58 bits/trit density', ru: 'плотность 1.58 бита/трит' },
    doi: '10.5281/zenodo.19227875',
    url: 'https://doi.org/10.5281/zenodo.19227875'
  },
  {
    id: 'B007',
    title: 'VSA Operations',
    metric: { en: '11.5× SIMD speedup', ru: 'ускорение SIMD в 11.5×' },
    doi: '10.5281/zenodo.19227877',
    url: 'https://doi.org/10.5281/zenodo.19227877'
  },
  {
    id: 'PARENT',
    title: 'Trinity S³AI Framework',
    metric: { en: 'All bundles integrated', ru: 'все бандлы собраны вместе' },
    doi: '10.5281/zenodo.19227879',
    url: 'https://doi.org/10.5281/zenodo.19227879'
  }
];

export default function PublicationsSection() {
  const { t: { publications: t }, lang } = useI18n();
  const M = (m: { en: string; ru: string }) => (lang === 'ru' ? m.ru : m.en);

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
              {M(pub.metric)}
            </div>

            <div style={{
              display: 'inline-flex',
              alignItems: 'center',
              fontSize: '0.75rem',
              color: 'var(--muted)', // был синий мимо палитры, контраст на грани
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
