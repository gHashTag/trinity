import { useEffect, useMemo, useRef, useState } from "react";

// The comb: the board drawn as a triangular tiling in which every cell IS the
// Trinity mark. Proven in six dependency-free prototypes under
// gHashTag/tri-27 docs/game/prototypes before it was written as a component;
// the geometry, the per-pass timings and the three defects found on the way
// are recorded there. Nothing here is a second data model: cells are the
// board's cards, bees are the research endpoint's worker slots, the same
// props QueenFactory already receives.

interface CombColumn {
  key: string;
  title: string;
}

interface CombCard {
  number: number;
  title: string;
  column: string;
  criteria?: number;
}

interface CombWorkers {
  capacity: number;
  active: number;
  idle: number;
  slots: Array<{ slot: number; state: "busy" | "idle" }>;
}

interface CombLabels {
  aria: string;
  held: string;
  neutral: string;
  fog: string;
  bees: string;
  queen: string;
  queenCell: string;
  noBee: string;
  pick: string;
  hint: string;
  offline: string;
}

interface QueenCombProps {
  columns: CombColumn[];
  cards: CombCard[];
  repo: string | null;
  workers: CombWorkers | null;
  error: string | null;
  labels: CombLabels;
}

// ---- the mark, parsed once at module load ---------------------------------
// 27 petal paths verbatim from public/trinity-logo-with-label.svg. Every
// petal is a pentagon: 135 edges, 108 vertices, of which exactly 27 are
// shared between petals - those are the lit nodes, one per petal.
const PETAL_PATHS = [
  "M543.609 639.667L490.537 546.456L468.444 585.304L543.609 717.477V639.667Z",
  "M489.786 545.199L438.209 453.966H393.861L467.788 584.09L489.786 545.199Z",
  "M384.525 360.512L436.994 452.791L393.091 452.811L319.18 322.035L384.525 360.512Z",
  "M319.922 320.841L385.231 358.858H489.638L468.408 320.815L319.922 320.841Z",
  "M469.854 320.81L491.695 358.618L596.337 358.912L618.433 320.801L469.854 320.81Z",
  "M703.129 359.011L598.207 358.965L619.983 321.06L767.697 321.125L703.129 359.011Z",
  "M702.54 360.827L650.501 452.677L695.338 452.697L769.614 321.531L702.54 360.827Z",
  "M598.155 544.433L620.701 584.062L694.724 453.922L649.575 453.972L598.155 544.433Z",
  "M544.819 639.162L597.407 545.611L619.959 585.522L544.819 717.812V639.162Z",
  "M543.946 567.149L511.486 510.031L491.755 544.962L543.946 636.825V567.149Z",
  "M510.857 508.805L479.79 454.184H440.322L490.965 543.644L510.857 508.805Z",
  "M479.052 452.892L447.096 396.758L387.857 362.23L439.599 453.267L479.052 452.892Z",
  "M389.427 361.072L447.673 395.597L511.235 395.595L491.23 360.678L389.427 361.072Z",
  "M512.836 395.557L576.043 395.537L595.834 360.751H492.923L512.836 395.557Z",
  "M577.573 395.548L641.433 395.482L700.284 360.835H597.379L577.573 395.548Z",
  "M641.979 396.644L609.958 452.951L649.135 452.858L700.736 362.59L641.979 396.644Z",
  "M578.24 508.803L597.734 543.266L648.408 454.174L609.263 454.131L578.24 508.803Z",
  "M545.483 567.025L577.45 510.047L597.043 544.548L545.483 635.215V567.025Z",
  "M543.157 496.408L530.886 474.893L511.632 508.976L543.157 564.23V496.408Z",
  "M510.799 507.831L530.268 473.478L519.428 454.358L480.586 454.341L510.799 507.831Z",
  "M506.749 432.127L518.606 453.09L479.871 453.107L448.64 398.108L506.749 432.127Z",
  "M507.208 431.026L530.649 431.016L511.365 397.077L449.27 397.105L507.208 431.026Z",
  "M512.645 397.101L531.982 430.989H555.007L574.428 397.101H512.645Z",
  "M580.435 431.079L556.539 431.069L575.922 397.106L638.353 397.134L580.435 431.079Z",
  "M580.705 432.287L568.987 453.102L607.741 453.119L638.937 398.141L580.705 432.287Z",
  "M576.766 507.787L557.383 473.503L568.216 454.334L607.09 454.317L576.766 507.787Z",
  "M544.716 496.337L556.648 474.865L575.81 509.007L544.716 564.007V496.337Z",
];

type Pt = [number, number];

function parsePath(d: string): Pt[] {
  const tokens = d.match(/[MLHVZ]|-?\d*\.?\d+/g) ?? [];
  const points: Pt[] = [];
  let command = "M";
  let x = 0;
  let y = 0;
  let i = 0;
  while (i < tokens.length) {
    const token = tokens[i];
    if (/[MLHVZ]/.test(token)) {
      command = token;
      i += 1;
      if (command === "Z") break;
      continue;
    }
    if (command === "H") {
      x = Number(tokens[i]);
      i += 1;
    } else if (command === "V") {
      y = Number(tokens[i]);
      i += 1;
    } else {
      x = Number(tokens[i]);
      y = Number(tokens[i + 1]);
      i += 2;
    }
    points.push([x, y]);
  }
  return points;
}

// The mark's silhouette, measured off the SVG: a point-down triangle, flat
// base at y=320.8 from x=319.9 to 769.6, apex at (544, 717.8). h/w = 0.881
// against 0.866 for an equilateral - close enough that the tiling closes when
// normalised to an exact equilateral of side 1.
const BASE_Y = 320.8;
const APEX_Y = 717.8;
const LEFT = 319.9;
const RIGHT = 769.6;
const MARK_W = RIGHT - LEFT;
const MARK_H = APEX_Y - BASE_Y;
const MARK_CX = (LEFT + RIGHT) / 2;
const HT = Math.sqrt(3) / 2;

const PETALS: Pt[][] = PETAL_PATHS.map((d) =>
  parsePath(d).map(([x, y]) => [
    (x - MARK_CX) / MARK_W,
    ((y - BASE_Y) / MARK_H) * HT - HT / 3,
  ]),
);

const EDGES: Array<[number, number, number, number]> = [];
const NODES: Array<{ x: number; y: number; ring: number }> = [];
{
  const seen = new Map<string, { x: number; y: number; ring: number; deg: number }>();
  PETALS.forEach((poly, petalIndex) => {
    const ring = Math.floor(petalIndex / 9);
    for (let i = 0; i < poly.length; i += 1) {
      const a = poly[i];
      const b = poly[(i + 1) % poly.length];
      EDGES.push([a[0], a[1], b[0], b[1]]);
      const key = `${a[0].toFixed(4)},${a[1].toFixed(4)}`;
      const hit = seen.get(key);
      if (hit) hit.deg += 1;
      else seen.set(key, { x: a[0], y: a[1], ring, deg: 1 });
    }
  });
  for (const v of seen.values()) if (v.deg >= 2) NODES.push(v);
}

// ---- field geometry ----------------------------------------------------------
const S = 150;
const HH = (S * Math.sqrt(3)) / 2;

type Territory = "held" | "neutral" | "fog";

interface Cell {
  x: number;
  y: number;
  yTop: number;
  up: boolean;
  own: Territory;
  card: CombCard | null;
  phase: number;
}

interface Bee {
  slot: number;
  busy: boolean;
  from: number;
  to: number;
  t: number;
  speed: number;
  line: "scribe" | "wright" | "lapidary";
}

// Which column means which ground. done/running: the swarm holds it. backlog
// and review: reachable, unclaimed. blocked/dropped: fog - nothing to scout.
function territoryOf(column: string): Territory {
  if (column === "done" || column === "running") return "held";
  if (column === "blocked" || column === "dropped") return "fog";
  return "neutral";
}

const LINES = ["scribe", "wright", "lapidary"] as const;

function corners(c: Cell): [Pt, Pt, Pt] {
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

// Rows are NOT shifted: row r owns the strip y in [r*HH, (r+1)*HH]; a
// down-cell has its base on the strip's top line, an up-cell the reverse.
// Alternating orientation on (c+r) makes every interior vertex the meeting
// point of exactly six cells. Verified on a 6x14 field before this was written.
function buildCells(cards: CombCard[]): Cell[] {
  const count = Math.max(27, cards.length);
  const rows = Math.max(3, Math.ceil(Math.sqrt(count / 2)));
  const cols = rows + 2;
  const cells: Cell[] = [];
  for (let r = 0; r < rows; r += 1) {
    for (let c = 0; c < cols * 2 - 1; c += 1) {
      const up = ((c + r) & 1) === 1;
      const x = (c - (cols * 2 - 2) / 2) * (S / 2);
      const yTop = (r - rows / 2) * HH;
      const cy = yTop + (up ? (HH * 2) / 3 : HH / 3);
      const i = cells.length;
      const card = cards[i] ?? null;
      cells.push({
        x,
        y: cy,
        yTop,
        up,
        own: card ? territoryOf(card.column) : "fog",
        card,
        phase: i * 0.37,
      });
    }
  }
  return cells;
}

function buildBees(workers: CombWorkers | null, cellCount: number): Bee[] {
  if (!workers) return [];
  return workers.slots.map((slot, i) => ({
    slot: slot.slot,
    busy: slot.state === "busy",
    from: (i * 7) % cellCount,
    to: (i * 7 + 4) % cellCount,
    t: (i % 5) / 5,
    speed: slot.state === "busy" ? 0.1 + 0.05 * (i % 3) : 0,
    line: LINES[i % 3],
  }));
}

// ---- sprites, loaded once per page ----------------------------------------
const SPRITES: Record<string, HTMLImageElement> = {};
const SPRITE_NAMES = [
  "queen",
  "larva",
  "scribe",
  "wright",
  "lapidary",
  "ground-held",
  "ground-neutral",
  "ground-fog",
];

function spriteImage(name: string): HTMLImageElement {
  let image = SPRITES[name];
  if (!image) {
    image = new Image();
    image.src = `./queen/${name}-256.png`;
    SPRITES[name] = image;
  }
  return image;
}

function ready(image: HTMLImageElement | undefined): image is HTMLImageElement {
  return Boolean(image && image.complete && image.naturalWidth > 0);
}

const GLINT: Record<string, HTMLCanvasElement> = {};
const NINE = [
  ["#FFD45A", "#00FF88", "#64DCFF"],
  ["#d4af37", "#00e599", "#3f9fc4"],
  ["#FF6B6B", "#ff66aa", "#7c5cff"],
];

function glint(key: string, color: string, alpha: number): HTMLCanvasElement {
  const cached = GLINT[key];
  if (cached) return cached;
  const r = 16;
  const canvas = document.createElement("canvas");
  canvas.width = r * 2;
  canvas.height = r * 2;
  const ctx = canvas.getContext("2d");
  if (ctx) {
    ctx.globalAlpha = alpha;
    const gradient = ctx.createRadialGradient(r, r, 0, r, r, r);
    gradient.addColorStop(0, "#fff");
    gradient.addColorStop(0.22, color);
    gradient.addColorStop(0.55, `${color}55`);
    gradient.addColorStop(1, `${color}00`);
    ctx.fillStyle = gradient;
    ctx.beginPath();
    ctx.arc(r, r, r, 0, Math.PI * 2);
    ctx.fill();
  }
  GLINT[key] = canvas;
  return canvas;
}

// ---- the component ---------------------------------------------------------
export function QueenComb({
  columns,
  cards,
  repo,
  workers,
  error,
  labels,
}: QueenCombProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const hostRef = useRef<HTMLDivElement>(null);
  const [picked, setPicked] = useState<number | null>(null);

  // Everything the frame loop reads lives in refs so the loop is created once
  // and never closes over stale props; React state only holds what the DOM
  // beside the canvas needs to re-render (the picked cell).
  // cells are a pure function of the cards, so they are memoised, not stored.
  // bees carry flight state the frame loop mutates, so they live in a ref for
  // the loop and are mirrored into state once per data change for the
  // inspector - the inspector needs only which cell a bee is at, which the
  // loop updates by mutating the same objects the state array holds.
  const cells = useMemo(() => buildCells(cards), [cards]);
  // bees are derived too: one per worker slot. The frame loop mutates their
  // flight fields in place, and the inspector reads the same objects, so a
  // memo is both the derivation and the shared identity - no state to sync.
  const bees = useMemo(() => buildBees(workers, cells.length), [workers, cells.length]);
  const cellsRef = useRef<Cell[]>(cells);
  const beesRef = useRef<Bee[]>(bees);
  const hoverRef = useRef(-1);
  const pickedRef = useRef(-1);
  const cameraRef = useRef({ yaw: 0, pitch: 0.62, dist: 420, auto: true });

  useEffect(() => {
    cellsRef.current = cells;
    beesRef.current = bees;
    // the loop's copy of the pick is a ref; keep it inside the new field
    if (pickedRef.current >= cells.length) pickedRef.current = -1;
  }, [cells, bees]);

  // A pick that outlives the field it was made on (the board shrank under it)
  // is invalid, and is treated as no pick at read time rather than being
  // reset from an effect - derived state, not synchronised state.
  const validPicked = picked !== null && picked < cells.length ? picked : null;

  useEffect(() => {
    const canvas = canvasRef.current;
    const host = hostRef.current;
    if (!canvas || !host) return;
    const ctx = canvas.getContext("2d", { alpha: false });
    if (!ctx) return;
    for (const name of SPRITE_NAMES) spriteImage(name);
    for (const line of LINES) {
      for (const stage of ["forager", "artisan", "warden", "archon"]) {
        spriteImage(`${line}-${stage}`);
      }
    }

    let width = 0;
    let height = 0;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const resize = () => {
      const rect = host.getBoundingClientRect();
      width = rect.width;
      height = rect.height;
      canvas.width = width * dpr;
      canvas.height = height * dpr;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    };
    resize();
    const observer = new ResizeObserver(resize);
    observer.observe(host);

    const camera = cameraRef.current;
    const project = (x: number, y: number, z: number) => {
      const cy = Math.cos(camera.yaw);
      const sy = Math.sin(camera.yaw);
      const cp = Math.cos(camera.pitch);
      const sp = Math.sin(camera.pitch);
      const X = x * cy + y * sy;
      const Y2 = -x * sy + y * cy;
      const Y = Y2 * cp - z * sp;
      const Z = Y2 * sp + z * cp;
      const f = camera.dist / (camera.dist + Z + 430);
      return [width / 2 + X * f, height / 2 + Y * f, Z, f] as const;
    };

    let drag: { x: number; y: number } | null = null;
    const local = (e: PointerEvent | MouseEvent) => {
      const rect = canvas.getBoundingClientRect();
      return [e.clientX - rect.left, e.clientY - rect.top] as const;
    };
    const onDown = (e: PointerEvent) => {
      const [x, y] = local(e);
      drag = { x, y };
      camera.auto = false;
      canvas.setPointerCapture(e.pointerId);
    };
    const onMove = (e: PointerEvent) => {
      const [x, y] = local(e);
      if (drag) {
        camera.yaw += (x - drag.x) * 0.006;
        camera.pitch = Math.max(0, Math.min(1.5, camera.pitch + (y - drag.y) * 0.005));
        drag = { x, y };
        return;
      }
      let best = -1;
      let bestDist = Number.POSITIVE_INFINITY;
      const cells = cellsRef.current;
      for (let i = 0; i < cells.length; i += 1) {
        const p = project(cells[i].x, cells[i].y, 0);
        const d = (p[0] - x) ** 2 + (p[1] - y) ** 2;
        if (d < bestDist) {
          bestDist = d;
          best = i;
        }
      }
      hoverRef.current = bestDist < (S * 0.3) ** 2 ? best : -1;
    };
    const onUp = () => {
      drag = null;
    };
    const onClick = () => {
      if (hoverRef.current >= 0) {
        pickedRef.current = hoverRef.current;
        setPicked(hoverRef.current);
      }
    };
    const onWheel = (e: WheelEvent) => {
      e.preventDefault();
      camera.dist = Math.max(150, Math.min(6000, camera.dist * (1 + e.deltaY * 0.0012)));
    };
    canvas.addEventListener("pointerdown", onDown);
    canvas.addEventListener("pointermove", onMove);
    window.addEventListener("pointerup", onUp);
    canvas.addEventListener("click", onClick);
    canvas.addEventListener("wheel", onWheel, { passive: false });

    let raf = 0;
    const t0 = performance.now();
    let last = t0;
    const GROUND: Record<Territory, string> = {
      held: "#0a1a12",
      neutral: "#090c0f",
      fog: "#040504",
    };
    const TEX_ALPHA: Record<Territory, number> = { held: 0.55, neutral: 0.38, fog: 0.2 };

    const render = (now: number) => {
      const dt = Math.min(now - last, 32);
      last = now;
      if (camera.auto) camera.yaw = Math.sin((now - t0) / 9000) * 0.35;
      const t = (now - t0) / 1000;
      const cells = cellsRef.current;
      const bees = beesRef.current;
      const pickedIndex = pickedRef.current;
      const hover = hoverRef.current;

      ctx.fillStyle = "#020806";
      ctx.fillRect(0, 0, width, height);

      // GROUND: flat colour by territory, then the engraved plate clipped in.
      for (let i = 0; i < cells.length; i += 1) {
        const c = cells[i];
        const k = corners(c).map(([px, py]) => project(px, py, 0));
        ctx.beginPath();
        ctx.moveTo(k[0][0], k[0][1]);
        ctx.lineTo(k[1][0], k[1][1]);
        ctx.lineTo(k[2][0], k[2][1]);
        ctx.closePath();
        ctx.fillStyle = i === pickedIndex ? "#12241a" : i === hover ? "#0d1a14" : GROUND[c.own];
        ctx.fill();
        const tex = SPRITES[`ground-${c.own}`];
        if (ready(tex)) {
          const xs = k.map((p) => p[0]);
          const ys = k.map((p) => p[1]);
          const bx = Math.min(...xs);
          const by = Math.min(...ys);
          const bw = Math.max(...xs) - bx;
          const bh = Math.max(...ys) - by;
          if (bw > 4 && bh > 4) {
            ctx.save();
            ctx.beginPath();
            ctx.moveTo(k[0][0], k[0][1]);
            ctx.lineTo(k[1][0], k[1][1]);
            ctx.lineTo(k[2][0], k[2][1]);
            ctx.closePath();
            ctx.clip();
            ctx.globalAlpha = TEX_ALPHA[c.own];
            ctx.drawImage(tex, bx, by, bw, bh);
            ctx.globalAlpha = 1;
            ctx.restore();
          }
        }
      }

      // WALLS: the mark's 135 edges per cell. Fog keeps its walls at a tenth
      // of the weight - fog of war dims a place, it does not delete it.
      for (const [which, stroke] of [
        ["fog", "rgba(232,232,240,.06)"],
        ["lit", "rgba(232,232,240,.46)"],
      ] as const) {
        ctx.strokeStyle = stroke;
        ctx.lineWidth = 0.7;
        ctx.beginPath();
        for (const c of cells) {
          if ((c.own === "fog") !== (which === "fog")) continue;
          const o = project(c.x, c.y, 0);
          const sc = S * o[3];
          const m = c.up ? -1 : 1;
          if (sc < 8) continue;
          for (const [ax, ay, bx, by] of EDGES) {
            ctx.moveTo(o[0] + ax * sc * m, o[1] + ay * sc * m);
            ctx.lineTo(o[0] + bx * sc * m, o[1] + by * sc * m);
          }
        }
        ctx.stroke();
      }
      ctx.strokeStyle = "rgba(0,255,136,.55)";
      ctx.lineWidth = 1.1;
      ctx.beginPath();
      for (const c of cells) {
        if (c.own !== "held") continue;
        const k = corners(c).map(([px, py]) => project(px, py, 0));
        ctx.moveTo(k[0][0], k[0][1]);
        ctx.lineTo(k[1][0], k[1][1]);
        ctx.lineTo(k[2][0], k[2][1]);
        ctx.closePath();
      }
      ctx.stroke();
      if (pickedIndex >= 0 && cells[pickedIndex]) {
        const k = corners(cells[pickedIndex]).map(([px, py]) => project(px, py, 0));
        ctx.strokeStyle = "#FFD45A";
        ctx.lineWidth = 1.8;
        ctx.beginPath();
        ctx.moveTo(k[0][0], k[0][1]);
        ctx.lineTo(k[1][0], k[1][1]);
        ctx.lineTo(k[2][0], k[2][1]);
        ctx.closePath();
        ctx.stroke();
      }

      // NODES: 27 per cell. With no per-card trit word yet, a held cell lights
      // gold, a neutral one cyan, a fog cell stays dark - the territory again,
      // at node scale, so the field reads the same at every zoom.
      ctx.globalCompositeOperation = "lighter";
      for (const c of cells) {
        if (c.own === "fog") continue;
        const o = project(c.x, c.y, 0);
        const sc = S * o[3];
        const m = c.up ? -1 : 1;
        if (sc < 8) continue;
        const tier = c.own === "held" ? 0 : 1;
        for (let vi = 0; vi < NODES.length; vi += 1) {
          const v = NODES[vi];
          const pulse = 0.55 + 0.45 * Math.sin(t * 1.6 + c.phase + vi * 0.21);
          const size = (tier === 0 ? 7 : 5) * (sc / 300) * (0.75 + 0.5 * pulse);
          if (size < 0.5) continue;
          const X = o[0] + v.x * sc * m;
          const Y = o[1] + v.y * sc * m;
          if (X < -size || X > width + size || Y < -size || Y > height + size) continue;
          const bright = pulse > 0.78 ? 2 : pulse > 0.5 ? 1 : 0;
          const alpha = [0.3, 0.58, 0.9][tier === 0 ? bright : Math.min(bright, 1)];
          const color = NINE[tier][v.ring];
          ctx.drawImage(glint(`${tier}:${v.ring}:${bright}`, color, alpha), X - size, Y - size, size * 2, size * 2);
        }
      }
      ctx.globalCompositeOperation = "source-over";

      // THE QUEEN on the centre cell.
      const queenIndex = Math.floor(cells.length / 2);
      const q = cells[queenIndex];
      const queenSprite = SPRITES.queen;
      if (q && ready(queenSprite)) {
        const c = project(q.x, q.y, 18);
        const qs = Math.max(20, S * 0.85 * c[3]);
        const sh = project(q.x, q.y, 0);
        ctx.fillStyle = "rgba(0,0,0,.6)";
        ctx.beginPath();
        ctx.ellipse(sh[0], sh[1], qs * 0.5, qs * 0.18, 0, 0, Math.PI * 2);
        ctx.fill();
        ctx.drawImage(queenSprite, c[0] - qs, c[1] - qs * 1.15, qs * 2, qs * 2);
      }

      // BEES: one per worker slot. Busy slots fly; idle slots sit as larvae.
      for (const b of bees) {
        if (b.busy) {
          b.t += (b.speed * dt) / 1000;
          if (b.t >= 1) {
            b.t = 0;
            b.from = b.to;
            b.to = (b.to + 3 + ((b.from * 7) % 5)) % cells.length;
          }
        }
        const A = cells[b.from];
        const B = cells[b.to];
        if (!A || !B) continue;
        const e = b.t < 0.5 ? 2 * b.t * b.t : 1 - 2 * (1 - b.t) * (1 - b.t);
        const x = A.x + (B.x - A.x) * e;
        const y = A.y + (B.y - A.y) * e;
        const arc = b.busy ? Math.sin(Math.PI * b.t) * 46 : 2;
        const c = project(x, y, arc);
        const sz = Math.max(7, S * 0.38 * c[3]);
        const sh = project(x, y, 0);
        ctx.fillStyle = "rgba(0,0,0,.55)";
        ctx.beginPath();
        ctx.ellipse(sh[0], sh[1], sz * 0.55, sz * 0.2, 0, 0, Math.PI * 2);
        ctx.fill();
        const image = b.busy ? SPRITES[b.line] : SPRITES.larva;
        if (ready(image)) {
          ctx.save();
          ctx.translate(c[0], c[1]);
          if (B.x - A.x < 0) ctx.scale(-1, 1);
          const bob = b.busy ? Math.sin(now / 90 + b.from) * sz * 0.04 : 0;
          ctx.drawImage(image, -sz, -sz + bob, sz * 2, sz * 2);
          ctx.restore();
        } else {
          ctx.fillStyle = "#FFD45A";
          ctx.beginPath();
          ctx.arc(c[0], c[1], sz * 0.25, 0, Math.PI * 2);
          ctx.fill();
        }
      }

      raf = window.requestAnimationFrame(render);
    };
    raf = window.requestAnimationFrame(render);

    return () => {
      window.cancelAnimationFrame(raf);
      observer.disconnect();
      canvas.removeEventListener("pointerdown", onDown);
      canvas.removeEventListener("pointermove", onMove);
      window.removeEventListener("pointerup", onUp);
      canvas.removeEventListener("click", onClick);
      canvas.removeEventListener("wheel", onWheel);
    };
  }, []);

  const held = cells.filter((c) => c.own === "held").length;
  const neutral = cells.filter((c) => c.own === "neutral").length;
  const fog = cells.filter((c) => c.own === "fog").length;
  const queenIndex = Math.floor(cells.length / 2);
  const pickedCell = validPicked !== null ? cells[validPicked] : null;
  const beeHere =
    validPicked !== null
      ? bees.find((b) => (b.t < 0.5 ? b.from : b.to) === validPicked)
      : undefined;
  const portrait =
    validPicked === queenIndex
      ? "queen"
      : beeHere && beeHere.busy
        ? beeHere.line
        : null;

  return (
    <div className="queen27-comb" role="region" aria-label={labels.aria}>
      <div className="queen27-comb-viewport">
        <div className="queen27-comb-legend" aria-hidden="true">
          <span>
            <b>{held}</b> {labels.held}
          </span>
          <span>
            <b>{neutral}</b> {labels.neutral}
          </span>
          <span>
            <b>{fog}</b> {labels.fog}
          </span>
          <span>
            <b>{workers?.active ?? 0}/{workers?.capacity ?? 0}</b> {labels.bees}
          </span>
        </div>
        <div className="queen27-comb-field" ref={hostRef}>
          <canvas ref={canvasRef} />
          <small className="queen27-comb-hint">{labels.hint}</small>
        </div>
      </div>
      <aside className="queen27-comb-inspector">
        {error && <p className="queen27-comb-error">{labels.offline}</p>}
        {validPicked === null || !pickedCell ? (
          <p className="queen27-comb-empty">{labels.pick}</p>
        ) : (
          <>
            {portrait ? (
              <img
                className="queen27-comb-portrait"
                src={`./queen/portrait-${portrait}-256.png`}
                alt=""
              />
            ) : (
              <i className="queen27-comb-portrait is-empty" aria-hidden="true" />
            )}
            <b className="queen27-comb-name">
              {validPicked === queenIndex
                ? labels.queen
                : beeHere && beeHere.busy
                  ? beeHere.line.toUpperCase()
                  : labels.noBee}
            </b>
            <small className="queen27-comb-stage">
              {validPicked === queenIndex ? labels.queenCell : pickedCell.own.toUpperCase()}
            </small>
            {pickedCell.card ? (
              <a
                className="queen27-comb-card"
                href={repo ? `https://github.com/${repo}/issues/${pickedCell.card.number}` : undefined}
                target="_blank"
                rel="noreferrer"
              >
                <span>#{pickedCell.card.number}</span>
                <strong>{pickedCell.card.title}</strong>
                <em>
                  {columns.find((col) => col.key === pickedCell.card?.column)?.title ??
                    pickedCell.card.column}
                  {typeof pickedCell.card.criteria === "number" && ` · ${pickedCell.card.criteria} CR`}
                </em>
              </a>
            ) : null}
          </>
        )}
      </aside>
    </div>
  );
}
