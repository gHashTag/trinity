interface ZigPlaygroundProps {
  height?: number;
}

export default function ZigPlayground({ height = 500 }: ZigPlaygroundProps): JSX.Element {
  return (
    <div style={{ marginBottom: '1.5rem' }}>
      <iframe
        src="https://zigland.dev/play"
        title="Zig Playground"
        style={{
          width: '100%',
          height,
          border: '1px solid var(--ifm-toc-border-color)',
          borderRadius: '8px'
        }}
        loading="lazy"
      />
    </div>
  );
}
