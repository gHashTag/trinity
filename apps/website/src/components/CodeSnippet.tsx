"use client";
import { useState, useCallback } from 'react';
import { motion } from 'framer-motion';

interface CodeSnippetProps {
  children: string;
  language?: string;
  onCopy?: () => void;
}

export default function CodeSnippet({ children, language = 'bash', onCopy }: CodeSnippetProps) {
  const [copied, setCopied] = useState(false);

  const handleCopy = useCallback(() => {
    navigator.clipboard.writeText(children);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
    onCopy?.();
  }, [children, onCopy]);

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.6, delay: 1.0 }}
      style={{
        position: 'relative',
        marginTop: '2rem',
        marginBottom: '2rem',
        borderRadius: '8px',
        overflow: 'hidden',
        background: 'rgba(0,0,0,0.4)',
        border: '1px solid rgba(0,255,136,0.2)',
      }}
    >
      <div style={{
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        padding: '0.5rem 1rem',
        background: 'rgba(0,255,136,0.1)',
        borderBottom: '1px solid rgba(0,255,136,0.2)',
      }}>
        <span style={{
          fontSize: '0.75rem',
          color: 'var(--accent)',
          textTransform: 'uppercase',
          letterSpacing: '0.1em',
        }}>{language}</span>
        <motion.button
          onClick={handleCopy}
          whileHover={{ scale: 1.05 }}
          whileTap={{ scale: 0.95 }}
          style={{
            background: copied ? 'rgba(0,255,136,0.3)' : 'transparent',
            border: '1px solid var(--accent)',
            color: copied ? '#00ff88' : 'var(--accent)',
            padding: '0.25rem 0.75rem',
            borderRadius: '4px',
            fontSize: '0.75rem',
            cursor: 'pointer',
            transition: 'all 0.2s',
          }}
          aria-label={copied ? 'Copied!' : 'Copy to clipboard'}
        >
          {copied ? '✓ Copied!' : 'Copy'}
        </motion.button>
      </div>
      <pre style={{
        margin: 0,
        padding: '1rem',
        overflow: 'auto',
        fontSize: 'clamp(0.75rem, 2vw, 0.875rem)',
        lineHeight: 1.6,
        color: '#e0e0e0',
      }}>
        <code>{children}</code>
      </pre>
    </motion.div>
  );
}
