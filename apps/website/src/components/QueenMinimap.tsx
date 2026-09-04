import { useEffect, useMemo, useRef } from "react";
import type { MouseEvent } from "react";
import type { CombCellSummary, HudCard, Territory } from "./queenHud";
import { HH, S, queenIndexOf, summariseCells } from "./QueenComb";
import "./QueenMinimap.css";

// The overview minimap of the HUD: the comb's field seen flat from above.
// It draws exactly the cells the comb draws - summariseCells is the comb's
// own buildCells with the flight state stripped - so a click here names the
// same index the comb would name, and the shell hands it back to the comb as
// `pickIndex`. Static: no frame loop, one redraw per data, pick or size change.

interface QueenMinimapProps {
  cards: (HudCard | null)[];
  picked: number | null;
  onPick?: (index: number) => void;
  labels: { aria: string };
}

type Pt = [number, number];

// Fill by territory, from the shell's palette: green held, cyan neutral, cold fog.
const FILL: Record<Territory, string> = {
  held: "rgba(0,255,136,.85)",
  neutral: "rgba(100,220,255,.75)",
  fog: "rgba(255,107,107,.6)",
};
// the platform under the buildings, and its rim (the comb's steel plate)
const PLATE = "#3a4150";
const PLATE_RIM = "#12161d";
const EDGE = "rgba(255,255,255,.12)";
const GOLD_FALLBACK = "#ffd700";
const PAD = 6;

// The same corners the comb computes: an up cell has its base on the strip's
// bottom line (yTop + HH) and its apex at yTop; a down cell the reverse.
function corners(c: CombCellSummary): [Pt, Pt, Pt] {
  const yB = c.yTop + HH;
  return c.up
    ? [
        [c.x - S / 2, yB],
        [c.x + S / 2, yB],
        [c.x, c.yTop],
      ]
    : [
        [c.x - S / 2, c.yTop],
        [c.x + S / 2, c.yTop],
        [c.x, yB],
      ];
}

/** Field-space to canvas-space: uniform scale, centred. */
interface Layout {
  scale: number;
  offsetX: number;
  offsetY: number;
}

function layoutFor(cells: CombCellSummary[], width: number, height: number): Layout {
  if (cells.length === 0 || width <= 0 || height <= 0) {
    return { scale: 1, offsetX: width / 2, offsetY: height / 2 };
  }
  let minX = Number.POSITIVE_INFINITY;
  let maxX = Number.NEGATIVE_INFINITY;
  let minY = Number.POSITIVE_INFINITY;
  let maxY = Number.NEGATIVE_INFINITY;
  for (const c of cells) {
    minX = Math.min(minX, c.x - S / 2);
    maxX = Math.max(maxX, c.x + S / 2);
    minY = Math.min(minY, c.yTop);
    maxY = Math.max(maxY, c.yTop + HH);
  }
  const fieldW = Math.max(maxX - minX, 1);
  const fieldH = Math.max(maxY - minY, 1);
  const scale = Math.max(
    Math.min((width - PAD * 2) / fieldW, (height - PAD * 2) / fieldH),
    0.0001,
  );
  return {
    scale,
    offsetX: width / 2 - ((minX + maxX) / 2) * scale,
    offsetY: height / 2 - ((minY + maxY) / 2) * scale,
  };
}

function draw(
  ctx: CanvasRenderingContext2D,
  cells: CombCellSummary[],
  picked: number | null,
  layout: Layout,
  width: number,
  height: number,
  gold: string,
) {
  const { scale, offsetX, offsetY } = layout;
  const toCanvas = ([x, y]: Pt): Pt => [offsetX + x * scale, offsetY + y * scale];
  const trace = (c: CombCellSummary) => {
    const k = corners(c).map(toCanvas);
    ctx.beginPath();
    ctx.moveTo(k[0][0], k[0][1]);
    ctx.lineTo(k[1][0], k[1][1]);
    ctx.lineTo(k[2][0], k[2][1]);
    ctx.closePath();
  };

  ctx.clearRect(0, 0, width, height);
  ctx.lineJoin = "round";
  // The map of the base (the user's StarCraft reference): the platform as a
  // plate, one square per building coloured by its territory, nothing on a
  // cell without a card. The cells keep their triangles for hit-testing.
  if (cells.length > 0) {
    let minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity;
    for (const c of cells) {
      const k = corners(c);
      for (const [px, py] of k) { minX = Math.min(minX, px); maxX = Math.max(maxX, px); minY = Math.min(minY, py); maxY = Math.max(maxY, py); }
    }
    const [ax, ay] = toCanvas([minX - S * 0.6, minY - S * 0.6]);
    const [bx, by] = toCanvas([maxX + S * 0.6, maxY + S * 0.6]);
    ctx.fillStyle = PLATE_RIM;
    ctx.fillRect(ax - 2, ay - 2, bx - ax + 4, by - ay + 4);
    ctx.fillStyle = PLATE;
    ctx.fillRect(ax, ay, bx - ax, by - ay);
    ctx.strokeStyle = EDGE;
    ctx.lineWidth = 1;
    ctx.strokeRect(ax + 0.5, ay + 0.5, bx - ax - 1, by - ay - 1);
  }
  const foot = Math.max(2, S * 0.36 * scale);
  for (const c of cells) {
    if (c.cardNumber === null) continue;
    const [cx, cy] = toCanvas([c.x, c.y]);
    ctx.fillStyle = FILL[c.own];
    ctx.fillRect(cx - foot / 2, cy - foot / 2, foot, foot);
  }

  if (picked !== null && picked >= 0 && picked < cells.length) {
    trace(cells[picked]);
    ctx.strokeStyle = gold;
    ctx.lineWidth = 1.5;
    ctx.stroke();
  }

  const queen = cells[queenIndexOf(cells.length)];
  if (queen) {
    // the centroid of either triangle is (x, y): y sits a third of the way
    // from the base, which is how buildCells placed it
    const [qx, qy] = toCanvas([queen.x, queen.y]);
    ctx.fillStyle = gold;
    ctx.beginPath();
    ctx.arc(qx, qy, 3, 0, Math.PI * 2);
    ctx.fill();
  }
}

export function QueenMinimap({ cards, picked, onPick, labels }: QueenMinimapProps) {
  const hostRef = useRef<HTMLDivElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  // The last layout drawn, for turning a click back into a field position.
  // Written by the draw effect, read by the click handler; never during render.
  const layoutRef = useRef<Layout>({ scale: 1, offsetX: 0, offsetY: 0 });

  const cells = useMemo(() => summariseCells(cards), [cards]);

  useEffect(() => {
    const host = hostRef.current;
    const canvas = canvasRef.current;
    if (!host || !canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);

    const paint = () => {
      const rect = host.getBoundingClientRect();
      const width = rect.width;
      const height = rect.height;
      canvas.width = Math.max(1, Math.round(width * dpr));
      canvas.height = Math.max(1, Math.round(height * dpr));
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      const gold = getComputedStyle(host).getPropertyValue("--hud-gold").trim() || GOLD_FALLBACK;
      const layout = layoutFor(cells, width, height);
      layoutRef.current = layout;
      draw(ctx, cells, picked, layout, width, height, gold);
    };

    // ResizeObserver delivers one notification on observe(), so the first
    // paint and every later resize go through the same path.
    const observer = new ResizeObserver(paint);
    observer.observe(host);
    return () => observer.disconnect();
  }, [cells, picked]);

  const handleClick = (event: MouseEvent<HTMLCanvasElement>) => {
    if (!onPick || cells.length === 0) return;
    const rect = event.currentTarget.getBoundingClientRect();
    const { scale, offsetX, offsetY } = layoutRef.current;
    if (scale <= 0) return;
    const fx = (event.clientX - rect.left - offsetX) / scale;
    const fy = (event.clientY - rect.top - offsetY) / scale;
    let best = -1;
    let bestDist = Number.POSITIVE_INFINITY;
    for (let i = 0; i < cells.length; i += 1) {
      const d = (cells[i].x - fx) ** 2 + (cells[i].y - fy) ** 2;
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    // within one cell: no point inside a triangle is farther than its
    // circumradius (S / sqrt 3 = 0.577 S) from the centroid
    if (best >= 0 && bestDist <= (S * 0.6) ** 2) onPick(best);
  };

  return (
    <div className="queen27-minimap" role="img" aria-label={labels.aria} ref={hostRef}>
      <canvas ref={canvasRef} onClick={handleClick} />
    </div>
  );
}
