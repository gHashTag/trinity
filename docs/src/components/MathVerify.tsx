import Playground from './Playground';

interface MathVerifyProps {
  formula: string;
  pythonCode: string;
  height?: number;
}

export default function MathVerify({
  formula,
  pythonCode,
  height = 300
}: MathVerifyProps): JSX.Element {
  return (
    <div className="math-verify" style={{ marginBottom: '1.5rem' }}>
      <div
        className="formula"
        style={{
          fontFamily: "'Times New Roman', serif",
          fontSize: '1.5rem',
          textAlign: 'center',
          padding: '1rem',
          marginBottom: '0.5rem',
          background: 'var(--ifm-background-surface-color)',
          borderRadius: '8px 8px 0 0',
          border: '1px solid var(--ifm-toc-border-color)',
          borderBottom: 'none',
        }}
      >
        {formula}
      </div>
      <Playground language="python" code={pythonCode} height={height} />
    </div>
  );
}
