import { useEffect, useRef } from 'react';
import { createPlayground } from 'livecodes';

interface PlaygroundProps {
  language?: 'python' | 'javascript' | 'typescript';
  code: string;
  height?: number;
  readOnly?: boolean;
}

export default function Playground({
  language = 'javascript',
  code,
  height = 350,
  readOnly = false
}: PlaygroundProps): JSX.Element {
  const containerRef = useRef<HTMLDivElement>(null);
  const playgroundRef = useRef<any>(null);

  useEffect(() => {
    if (containerRef.current && !playgroundRef.current) {
      createPlayground(containerRef.current, {
        config: {
          activeEditor: 'script',
          script: {
            language,
            content: code.trim()
          },
          tools: {
            enabled: ['console'],
            active: 'console',
            status: 'open',
          },
          readonly: readOnly,
        },
      }).then((playground) => {
        playgroundRef.current = playground;
      });
    }

    return () => {
      if (playgroundRef.current) {
        playgroundRef.current.destroy();
        playgroundRef.current = null;
      }
    };
  }, []);

  return (
    <div
      ref={containerRef}
      style={{
        height,
        border: '1px solid var(--ifm-toc-border-color)',
        borderRadius: '8px',
        overflow: 'hidden',
        marginBottom: '1rem',
      }}
    />
  );
}
