/**
 * Exact operational mark for the Queen scheduler.
 *
 * The triangle and the three orbits share one 240 x 240 coordinate system.
 * The primary triangle is equilateral and its centroid is exactly (120, 120),
 * so responsive scaling cannot introduce the offset that appeared when the
 * interactive petal logo was placed inside separately-sized CSS circles.
 */
export function QueenCycleGlyph() {
  return (
    <svg
      className="queen27-cycle-glyph"
      viewBox="0 0 240 240"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      aria-hidden="true"
      focusable="false"
      shapeRendering="geometricPrecision"
    >
      <circle
        data-role="orbit"
        className="queen27-cycle-orbit queen27-cycle-orbit-outer"
        cx="120"
        cy="120"
        r="118"
      />
      <circle
        data-role="orbit"
        className="queen27-cycle-orbit queen27-cycle-orbit-dashed"
        cx="120"
        cy="120"
        r="92"
      />
      <circle
        data-role="orbit"
        className="queen27-cycle-orbit queen27-cycle-orbit-inner"
        cx="120"
        cy="120"
        r="58"
      />

      <g className="queen27-cycle-triangles">
        <polygon
          data-role="primary-triangle"
          points="68.038476,90 171.961524,90 120,180"
        />
        <polygon points="85.358984,100 154.641016,100 120,160" />
        <polygon points="102.679492,110 137.320508,110 120,140" />
        <path d="M68.038476 90 120 140 171.961524 90M85.358984 100 120 180 154.641016 100M102.679492 110 120 160 137.320508 110" />
      </g>
      <circle className="queen27-cycle-core" cx="120" cy="120" r="3" />
    </svg>
  );
}
