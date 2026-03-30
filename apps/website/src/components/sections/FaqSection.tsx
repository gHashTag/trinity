"use client";
import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useI18n } from '../../i18n/context';

interface FaqItem {
  question: string;
  answer: string;
}

export default function FaqSection() {
  const { t } = useI18n();
  const [openIndex, setOpenIndex] = useState<number | null>(null);

  const toggle = (index: number) => {
    setOpenIndex(openIndex === index ? null : index);
  };

  const faqs: FaqItem[] = [
    {
      question: 'What is ternary computing?',
      answer: 'Ternary computing uses three values {-1, 0, +1} instead of binary {0, 1}. Each trit carries 1.585 bits of information (log₂(3) ≈ 1.585), making it 58% more information-dense than binary. This enables 20× memory compression and multiplication-free inference for AI models.',
    },
    {
      question: 'Do I need an FPGA to use Trinity?',
      answer: 'No. Trinity is fully compatible with standard GPUs, CPUs, and cloud platforms. The FPGA version provides 1000× energy efficiency for edge devices and data centers, but it\'s optional. All Trinity tools work with your existing hardware.',
    },
    {
      question: 'How does experience persistence work?',
      answer: 'Trinity uses .trinity/experience/ directory to permanently store learned patterns, successful workflows, and optimized configurations. Every agent run saves its learnings to this persistent store. When you encounter a similar problem, Trinity reuses these lessons instead of starting from scratch.',
    },
    {
      question: 'Is Trinity free and open source?',
      answer: 'Yes. Trinity is 100% open source under MIT license. All code, specifications, and documentation are freely available. You can run it locally, deploy it to your own infrastructure, or contribute to development.',
    },
    {
      question: 'How does φ² + 1/φ² = 3 relate to AI?',
      answer: 'This mathematical identity connects the golden ratio (φ) to optimal ternary computing. φ² + 1/φ² = 3 encodes a fundamental constant from nature (φ) into the architecture. This identity validates that Trinity\'s ternary design is mathematically optimal and aligned with universal patterns.',
    },
  ];

  return (
    <section id="faq" aria-labelledby="faq-heading" style={{
      padding: 'clamp(3rem, 8vw, 6rem) 1rem',
      maxWidth: '900px',
      margin: '0 auto',
    }}>
      <motion.h2
        id="faq-heading"
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
        {t.faq?.title || 'Frequently Asked Questions'}
      </motion.h2>

      <div style={{ maxWidth: '700px', margin: '0 auto' }}>
        {faqs.map((faq, index) => (
          <motion.div key={index} style={{ marginBottom: '1rem' }}>
            <motion.button
              onClick={() => toggle(index)}
              style={{
                width: '100%',
                textAlign: 'left',
                padding: '1.25rem 1.5rem',
                background: 'rgba(0,0,0,0.3)',
                borderRadius: '8px',
                border: '1px solid rgba(0,255,136,0.2)',
                cursor: 'pointer',
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
              }}
              aria-expanded={openIndex === index}
              aria-controls={`faq-answer-${index}`}
            >
              <span style={{
                fontSize: 'clamp(0.95rem, 2.5vw, 1.1rem)',
                fontWeight: 500,
                color: 'var(--text)',
              }}>
                {faq.question}
              </span>
              <motion.span
                animate={{ rotate: openIndex === index ? 180 : 0 }}
                transition={{ duration: 0.3 }}
                style={{
                  display: 'inline-block',
                  color: 'var(--accent)',
                  fontSize: '1.25rem',
                }}
              >
                {openIndex === index ? '−' : '+'}
              </motion.span>
            </motion.button>
            <AnimatePresence>
              {openIndex === index && (
                <motion.div
                  id={`faq-answer-${index}`}
                  initial={{ opacity: 0, height: 0 }}
                  animate={{ opacity: 1, height: 'auto' }}
                  exit={{ opacity: 0, height: 0 }}
                  transition={{ duration: 0.3 }}
                  style={{
                    padding: '1.5rem',
                    background: 'rgba(0,0,0,0.2)',
                    borderRadius: '0 0 8px 8px',
                    borderLeft: '4px solid var(--accent)',
                    marginTop: '0.5rem',
                  }}
                  role="region"
                >
                  <p style={{
                    fontSize: 'clamp(0.9rem, 2vw, 1rem)',
                    color: 'var(--text-secondary)',
                    lineHeight: 1.7,
                    margin: 0,
                  }}>
                    {faq.answer}
                  </p>
                </motion.div>
              )}
            </AnimatePresence>
          </motion.div>
        ))}
      </div>
    </section>
  );
}
