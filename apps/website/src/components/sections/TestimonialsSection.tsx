"use client";
import { motion } from 'framer-motion';
import { useI18n } from '../../i18n/context';

interface Testimonial {
  quote: string;
  author: string;
  context?: string;
}

export default function TestimonialsSection() {
  const { t } = useI18n();

  // Placeholder testimonials - can be extracted from GitHub issues later
  const testimonials: Testimonial[] = [
    {
      quote: 'Finally, an AI agent that remembers my workflows. Every project builds on what I learned before.',
      author: 'GitHub User',
      context: 'Experience persistence',
    },
    {
      quote: 'The CLI is exactly what I needed — all my tools in one place, with intelligent agent coordination.',
      author: 'Developer',
      context: 'Unified interface',
    },
    {
      quote: 'Installation was painless, and the 27-agent architecture actually makes sense when you see it working together.',
      author: 'Contributor',
      context: 'Multi-agent system',
    },
    {
      quote: 'I was skeptical about ternary computing until I ran the benchmarks. 298K tokens/s on RTX 3090 is real.',
      author: 'Researcher',
      context: 'Performance verification',
    },
  ];

  return (
    <section id="testimonials" aria-labelledby="testimonials-heading" style={{
      padding: 'clamp(3rem, 8vw, 6rem) 1rem',
      maxWidth: '1000px',
      margin: '0 auto',
    }}>
      <motion.h2
        id="testimonials-heading"
        className="fade"
        initial={{ opacity: 0, y: 20 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true }}
        transition={{ duration: 0.6 }}
        style={{
          textAlign: 'center',
          fontSize: 'clamp(1.5rem, 4vw, 2.25rem)',
          marginBottom: '2rem',
          color: 'var(--text)',
        }}
      >
        {t.testimonials?.title || 'What Developers Say'}
      </motion.h2>

      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
        gap: '2rem',
      }}>
        {testimonials.map((testimonial, i) => (
          <motion.div
            key={i}
            initial={{ opacity: 0, y: 30 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5, delay: i * 0.1 }}
            style={{
              padding: '2rem',
              background: 'rgba(0,0,0,0.3)',
              borderRadius: '12px',
              border: '1px solid rgba(0,255,136,0.15)',
            }}
          >
            <blockquote style={{
              margin: 0,
              marginBottom: '1rem',
            }}>
              <p style={{
                fontSize: 'clamp(1rem, 2.5vw, 1.15rem)',
                fontStyle: 'italic',
                color: 'var(--text)',
                lineHeight: 1.7,
                marginBottom: '0.5rem',
              }}>
                "{testimonial.quote}"
              </p>
            </blockquote>
            <div style={{
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              borderTop: '1px solid rgba(0,255,136,0.2)',
              paddingTop: '1rem',
            }}>
              <div>
                <div style={{
                  fontWeight: 600,
                  fontSize: '0.95rem',
                  color: 'var(--text)',
                  marginBottom: '0.25rem',
                }}>
                  {testimonial.author}
                </div>
                {testimonial.context && (
                  <div style={{
                    fontSize: '0.85rem',
                    color: 'var(--text-tertiary)',
                  }}>
                    {testimonial.context}
                  </div>
                )}
              </div>
            </div>
          </motion.div>
        ))}
      </div>
    </section>
  );
}
