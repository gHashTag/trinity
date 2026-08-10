/**
 * Says, on screen, that the numbers beside it are placeholders.
 *
 * chatApi tags every fallback object with `__sample` (see `sample()` there).
 * Without a visible marker those literals read as measurements: anomaly A36
 * found `novelty: 0.342` presented as a consciousness-guided FPGA reading on
 * a public route. This component is the other half of that fix.
 */
export function SampleBadge({ of }: { of: unknown }) {
  const isSample = !!of && typeof of === 'object' && '__sample' in (of as object);
  if (!isSample) return null;
  return (
    <span
      title="No response from the API — these are placeholder values, not measurements."
      style={{ marginLeft: 8, fontWeight: 400, fontSize: '0.75em', color: 'rgba(255,170,0,0.9)' }}
    >
      ● SAMPLE DATA
    </span>
  );
}
