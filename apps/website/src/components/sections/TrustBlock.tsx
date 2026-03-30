"use client";
import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { useI18n } from '../../i18n/context';

interface Metric {
  value: string;
  label: string;
  source: string;
}

interface TrustBlockProps {
  metrics?: Metric[];
}

export default function TrustBlock({ metrics: propMetrics }: TrustBlockProps) {
  const { t } = useI18n();
  const [stars, setStars] = useState<number>(1500); // Static fallback
  const [loading, setLoading] = useState(true);

  const defaultMetrics: Metric[] = [
    { value: `${stars}+`, label: 'GitHub Stars', source: 'github.com/gHashTag/trinity' },
    { value: '310+', label: 'CLI Commands', source: 'src/tri/' },
    { value: '7', label: 'Zenodo Publications', source: 'DOI-verified' },
    { value: '98.7%', label: 'Test Coverage', source: 'TRI-27 ISA tests' },
    { value: '27', label: 'Agent Modules', source: 'Coptic alphabet' },
  ];

  const metrics = propMetrics || defaultMetrics;

  // Fetch GitHub stars with caching
  useEffect(() => {
    const cacheKey = 'trinity-github-stars';
    const cacheTime = localStorage.getItem(`${cacheKey}-time`);
    const now = Date.now();

    // Use cache if less than 5 minutes old
    if (cacheTime && now - parseInt(cacheTime) < 300000) {
      const cachedStars = localStorage.getItem(cacheKey);
      if (cachedStars) {
        setStars(parseInt(cachedStars));
        setLoading(false);
        return;
      }
    }

    // Fetch from GitHub API
    fetch('https://api.github.com/repos/gHashTag/trinity')
      .then(res => {
        if (!res.ok) throw new Error('Rate limited');
        return res.json();
      })
      .then(data => {
        const starCount = data.stargazers_count || 1500;
        setStars(starCount);
        localStorage.setItem(cacheKey, starCount.toString());
        localStorage.setItem(`${cacheKey}-time`, now.toString());
        setLoading(false);
      })
      .catch(() => {
        // Keep static fallback on error
        setLoading(false);
      });
  }, []);

  return (
    <section id="trust" aria-labelledby="trust-heading" style={{
      padding: 'clamp(2rem, 5vw, 4rem) 1rem',
      maxWidth: '1200px',
      margin: '0 auto',
    }}>
      <motion.h2
        id="trust-heading"
        className="fade"
        initial={{ opacity: 0, y: 20 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true }}
        transition={{ duration: 0.6 }}
        style={{
          textAlign: 'center',
          fontSize: 'clamp(1.25rem, 3vw, 1.75rem)',
          marginBottom: '3rem',
          color: 'var(--text)',
        }}
      >
        {t.trustBlock?.title || 'Trusted by Developers'}
      </motion.h2>

      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
        gap: 'clamp(1rem, 3vw, 2rem)',
        alignItems: 'center',
        justifyContent: 'center',
      }}>
        {metrics.map((metric, i) => (
          <motion.div
            key={i}
            className="fade"
            initial={{ opacity: 0, scale: 0.9 }}
            whileInView={{ opacity: 1, scale: 1 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5, delay: i * 0.1 }}
            style={{
              textAlign: 'center',
              padding: '1.5rem',
              background: 'rgba(0,0,0,0.2)',
              borderRadius: '8px',
              border: '1px solid rgba(0,255,136,0.1)',
            }}
          >
            <div style={{
              fontSize: 'clamp(2rem, 5vw, 2.5rem)',
              fontWeight: 700,
              color: 'var(--accent)',
              marginBottom: '0.5rem',
            }}>
              {loading && i === 0 ? '...' : metric.value}
            </div>
            <div style={{
              fontSize: 'clamp(0.8rem, 2vw, 0.9rem)',
              color: 'var(--text-secondary)',
              marginBottom: '0.25rem',
            }}>
              {metric.label}
            </div>
            <div style={{
              fontSize: '0.7rem',
              color: 'var(--text-tertiary)',
            }}>
              {metric.source}
            </div>
          </motion.div>
        ))}
      </div>
    </section>
  );
}
