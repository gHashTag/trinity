import "./QueenLoading.css";

/**
 * The one loader this shell uses.
 *
 * Every waiting state here was a line of text — "BUILDING THE MAP…", "Loading
 * GitHub world…", the specs frame's own word — each written where it happened
 * and none of them saying anything. A loader that only announces that something
 * is loading tells the reader what they already know from the empty screen.
 *
 * This one carries facts: the counts the wait is for, from the data the caller
 * already holds. Nothing here is invented — a caller with no numbers yet passes
 * none, and then it is a title and a bar, which is honest about knowing nothing.
 */
export interface QueenLoadingProps {
  /** What is being built, in the caller's words. */
  title: string;
  /** Real counts, already known: ["2176 cells", "760 .t27", "5 repositories"]. */
  facts?: (string | null | undefined)[];
  /** Fills its parent by default; false when it sits inside a panel's flow. */
  fill?: boolean;
}

export function QueenLoading({ title, facts, fill = true }: QueenLoadingProps) {
  const shown = (facts ?? []).filter((fact): fact is string => !!fact && fact.trim() !== "");
  return (
    <div className="queen-loading" data-fill={fill ? "1" : undefined} role="status">
      {/* The mark the rest of this HUD is drawn from: a point-down triangle,
          turning while there is nothing else to show. */}
      <svg className="queen-loading-mark" viewBox="0 0 32 32" aria-hidden="true">
        <polygon points="16,27 3,5 29,5" />
        <polygon points="16,20 9.5,9 22.5,9" />
      </svg>
      <strong>{title}</strong>
      {shown.length > 0 && (
        <p>
          {shown.map((fact, index) => (
            <span key={fact}>
              {index > 0 && <i aria-hidden="true"> · </i>}
              {fact}
            </span>
          ))}
        </p>
      )}
      <span className="queen-loading-bar" aria-hidden="true" />
    </div>
  );
}

export default QueenLoading;
