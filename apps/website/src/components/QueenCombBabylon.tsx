// The comb in Babylon.js (the user's decision, 2026-09-04 09:52Z: "Babylon").
// Behind `?engine=babylon` until it passes the pick, placement and touch
// contracts (check:queen-babylon) at visual parity with the canvas comb; the
// default then flips. Same field: summariseCells lays the islands, the
// mark's 135 edges and 27 nodes come from QueenComb's tables, the sprites
// are the same PNGs. Selective imports on purpose - the UMD bundle is 6.2x
// larger than what this file pulls in.
import { useEffect, useRef } from "react";
import { Engine } from "@babylonjs/core/Engines/engine";
import { Scene } from "@babylonjs/core/scene";
import { ArcRotateCamera } from "@babylonjs/core/Cameras/arcRotateCamera";
import { Camera } from "@babylonjs/core/Cameras/camera";
import { Vector3 } from "@babylonjs/core/Maths/math.vector";
import { Color3, Color4 } from "@babylonjs/core/Maths/math.color";
import { Mesh } from "@babylonjs/core/Meshes/mesh";
import { VertexData } from "@babylonjs/core/Meshes/mesh.vertexData";
import { VertexBuffer } from "@babylonjs/core/Buffers/buffer";
import { StandardMaterial } from "@babylonjs/core/Materials/standardMaterial";
import { Texture } from "@babylonjs/core/Materials/Textures/texture";
import { SpriteManager } from "@babylonjs/core/Sprites/spriteManager";
import { Sprite } from "@babylonjs/core/Sprites/sprite";
import { CreateLineSystem } from "@babylonjs/core/Meshes/Builders/linesBuilder";
import type { LinesMesh } from "@babylonjs/core/Meshes/linesMesh";
import { PointerEventTypes } from "@babylonjs/core/Events/pointerEvents";
import "@babylonjs/core/Culling/ray";
import { S, HH, EDGES, NODES, NINE, summariseCells, queenIndexOf } from "./QueenComb";
import { crystalOf, eventTone, type BeeLine, type HudEvent, type HudPick, type Tone } from "./queenHud";

interface SpikeCard {
  number: number;
  title: string;
  column: string;
  criteria?: number;
}

interface SpikeWorkers {
  slots: Array<{ slot: number; state: "busy" | "idle" }>;
}

interface QueenCombBabylonProps {
  cards: (SpikeCard | null)[];
  workers: SpikeWorkers | null;
  devices: Array<{ family: string }> | null;
  onPick?: (pick: HudPick | null) => void;
  pickIndex?: number | null;
  /** Fraction (0..1) of the host's height covered at the bottom by the context panel. */
  fitInset?: number;
  /** The activity feed: every event names an issue; its cell glints once per new event. */
  events?: HudEvent[];
}

const LINES: readonly BeeLine[] = ["scribe", "wright", "lapidary"];
const TONE_HEX: Record<Tone, string> = { gold: "#FFD45A", cold: "#FF6B6B", green: "#00FF88", cyan: "#64DCFF", muted: "#FFFFFF" };
const EMPTY_EVENTS: HudEvent[] = [];
const RING_POOL = 24;

type Territory = "held" | "neutral" | "fog";
const TEX_ALPHA: Record<Territory, number> = { held: 0.85, neutral: 0.7, fog: 0.35 };
const GROUND: Record<Territory, string> = { held: "#0a1a12", neutral: "#090c0f", fog: "#040504" };
const DEPTH = 9;
const TERRITORIES: Territory[] = ["held", "neutral", "fog"];

/** Point-in-down-triangle for the cell under a world point (x, z). */
function cellAtWorld(cells: ReturnType<typeof summariseCells>, wx: number, wz: number): number {
  for (let i = 0; i < cells.length; i += 1) {
    const c = cells[i];
    const ax = c.x - S / 2, ay = c.yTop;
    const bx = c.x + S / 2, by = c.yTop;
    const cx = c.x, cy = c.yTop + HH;
    const d1 = (wx - bx) * (ay - by) - (ax - bx) * (wz - by);
    const d2 = (wx - cx) * (by - cy) - (bx - cx) * (wz - cy);
    const d3 = (wx - ax) * (cy - ay) - (cx - ax) * (wz - ay);
    const neg = d1 < 0 || d2 < 0 || d3 < 0;
    const pos = d1 > 0 || d2 > 0 || d3 > 0;
    if (!(neg && pos)) return i;
  }
  return -1;
}

/** The glint sprite sheet: one radial glint per (tier, ring) cell, 32 px each, as a data URL. */
function glintSheet(): { url: string; cell: number; count: number } {
  const cell = 32, r = 16;
  const keys: string[] = [];
  NINE.forEach((row) => row.forEach((color) => keys.push(color)));
  const canvas = document.createElement("canvas");
  canvas.width = cell * keys.length; canvas.height = cell;
  const ctx = canvas.getContext("2d");
  if (ctx) keys.forEach((color, k) => {
    const g = ctx.createRadialGradient(k * cell + r, r, 0, k * cell + r, r, r);
    g.addColorStop(0, "#fff"); g.addColorStop(0.22, color); g.addColorStop(0.55, `${color}55`); g.addColorStop(1, `${color}00`);
    ctx.fillStyle = g; ctx.beginPath(); ctx.arc(k * cell + r, r, r, 0, Math.PI * 2); ctx.fill();
  });
  return { url: canvas.toDataURL("image/png"), cell, count: keys.length };
}

export function QueenCombBabylon({ cards, workers, devices, onPick, pickIndex = null, fitInset = 0, events = EMPTY_EVENTS }: QueenCombBabylonProps) {
  const hostRef = useRef<HTMLDivElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const onPickRef = useRef(onPick);
  const pickRef = useRef<number | null>(pickIndex);
  const insetRef = useRef(fitInset);
  const eventsRef = useRef(events);
  // Which events already glinted, across scene rebuilds: the feed is a
  // 120-event ring, and the first batch is history (only its last 30 s glint).
  const seenEventsRef = useRef<Set<string>>(new Set());
  const eventsPrimedRef = useRef(false);
  useEffect(() => {
    onPickRef.current = onPick;
    pickRef.current = pickIndex;
    insetRef.current = fitInset;
    eventsRef.current = events;
  }, [onPick, pickIndex, fitInset, events]);

  // The pollers hand over new arrays every 5 s; the scene is rebuilt only
  // when what they carry changes (cell -> card number/column, slot states,
  // device families). Fine-grained updates without a rebuild are B-3.
  const signature = JSON.stringify([
    cards.map((c) => (c ? [c.number, c.column] : null)),
    workers?.slots.map((s) => [s.slot, s.state]) ?? null,
    devices?.map((d) => d.family) ?? null,
  ]);
  const cardsRef = useRef(cards);
  const workersRef = useRef(workers);
  const devicesRef = useRef(devices);
  useEffect(() => {
    cardsRef.current = cards;
    workersRef.current = workers;
    devicesRef.current = devices;
  }, [cards, workers, devices]);

  useEffect(() => {
    const canvas = canvasRef.current;
    const host = hostRef.current;
    if (!canvas || !host) return;
    const cards = cardsRef.current;
    const workers = workersRef.current;
    const devices = devicesRef.current;
    const cells = summariseCells(cards);
    const home = queenIndexOf(cells.length);
    const engine = new Engine(canvas, true, { preserveDrawingBuffer: false, stencil: false }, false);
    const scene = new Scene(engine);
    scene.clearColor = new Color4(2 / 255, 8 / 255, 6 / 255, 1);
    scene.skipPointerMovePicking = true;

    // ---- extents and camera (orthographic, the canvas comb's pitch) --------
    let minX = Infinity, maxX = -Infinity, minZ = Infinity, maxZ = -Infinity;
    for (const c of cells) {
      minX = Math.min(minX, c.x - S / 2); maxX = Math.max(maxX, c.x + S / 2);
      minZ = Math.min(minZ, c.yTop); maxZ = Math.max(maxZ, c.yTop + HH);
    }
    const centre = new Vector3((minX + maxX) / 2, 0, (minZ + maxZ) / 2);
    const camera = new ArcRotateCamera("cam", Math.PI / 2, Math.PI / 2 - 0.62, 3000, centre.clone(), scene);
    camera.mode = Camera.ORTHOGRAPHIC_CAMERA;
    camera.lowerBetaLimit = 0.35;
    camera.upperBetaLimit = 1.35;
    camera.panningSensibility = 0;
    let zoom = 1;
    let manual = false;
    let appliedInset = -1;
    // The field is fitted into the band above the context panel and centred
    // there: the ortho window is asymmetric by the inset, which shifts the
    // field up by half the covered height in screen space.
    const fit = () => {
      const w = host.clientWidth || 1, h = host.clientHeight || 1;
      const inset = insetRef.current;
      const band = h * (1 - inset);
      const fieldW = (maxX - minX) * 1.05, fieldH = (maxZ - minZ) * Math.cos(camera.beta) * 1.05 + DEPTH;
      const aspect = w / band;
      let halfW = fieldW / 2, halfH = halfW / aspect;
      if (halfH < fieldH / 2) { halfH = fieldH / 2; halfW = halfH * aspect; }
      halfW /= zoom; halfH /= zoom;
      const unitsPerPx = (halfH * 2) / band;
      const shift = (h - band) * unitsPerPx; // world units of screen height covered by the panel
      camera.orthoLeft = -halfW; camera.orthoRight = halfW;
      camera.orthoTop = halfH; camera.orthoBottom = -halfH - shift;
      appliedInset = inset;
    };
    fit();
    camera.attachControl(canvas, true);
    canvas.addEventListener("wheel", (e) => { e.preventDefault(); manual = true; zoom = Math.min(8, Math.max(0.4, zoom * (e.deltaY < 0 ? 1.1 : 1 / 1.1))); fit(); }, { passive: false });
    camera.onViewMatrixChangedObservable.add(() => { if (camera.inertialAlphaOffset !== 0) manual = true; });

    // ---- materials ----------------------------------------------------------
    const flat = (name: string, hex: string, alpha = 1) => {
      const m = new StandardMaterial(name, scene);
      m.emissiveColor = Color3.FromHexString(hex);
      m.disableLighting = true;
      m.backFaceCulling = false;
      m.alpha = alpha;
      return m;
    };
    const plateMat: Record<Territory, StandardMaterial> = { held: flat("plate-held", GROUND.held), neutral: flat("plate-neutral", GROUND.neutral), fog: flat("plate-fog", GROUND.fog) };
    const soilMat: Record<Territory, StandardMaterial> = {} as Record<Territory, StandardMaterial>;
    for (const own of TERRITORIES) {
      const m = new StandardMaterial(`soil-${own}`, scene);
      const t = new Texture(`./queen/ground-${own}-256.png`, scene, false, true);
      t.hasAlpha = true;
      m.diffuseTexture = t;
      m.emissiveColor = Color3.White();
      m.disableLighting = true;
      m.useAlphaFromDiffuseTexture = true;
      m.alpha = TEX_ALPHA[own];
      m.backFaceCulling = false;
      soilMat[own] = m;
    }
    const sideMat = flat("side", "#06100c");

    const byTerritory: Record<Territory, number[]> = { held: [], neutral: [], fog: [] };
    cells.forEach((c, i) => byTerritory[c.own as Territory].push(i));
    const phase = (i: number) => i * 0.37;
    const bob = (i: number, t: number) => 6 + Math.sin(t * 0.6 + phase(i) * 1.7) * 4;
    const tri = (i: number): [number, number][] => { const c = cells[i]; return [[c.x - S / 2, c.yTop], [c.x + S / 2, c.yTop], [c.x, c.yTop + HH]]; };

    // ---- ground: plate (opaque fill) + soil (textured, translucent) per territory,
    //      sides + undersides in one mesh; every vertex remembers its island so
    //      the bob moves an island as one body ----------------------------------
    interface Batch { mesh: Mesh; base: Float32Array; owners: number[]; lift: number }
    const batches: Batch[] = [];
    const topMesh = (name: string, idx: number[], material: StandardMaterial, lift: number, pickable: boolean) => {
      const positions: number[] = [], indices: number[] = [], uvs: number[] = [], owners: number[] = [];
      idx.forEach((i) => {
        const c = cells[i];
        const v = positions.length / 3;
        for (const [px, pz] of tri(i)) {
          positions.push(px, lift, pz);
          uvs.push((px - (c.x - S / 2)) / S, 1 - (pz - c.yTop) / HH);
          owners.push(i);
        }
        indices.push(v, v + 2, v + 1);
      });
      const mesh = new Mesh(name, scene);
      const vd = new VertexData();
      vd.positions = positions; vd.indices = indices; vd.uvs = uvs;
      vd.applyToMesh(mesh, true);
      mesh.material = material;
      mesh.isPickable = pickable;
      batches.push({ mesh, base: Float32Array.from(positions), owners, lift });
    };
    for (const own of TERRITORIES) {
      if (!byTerritory[own].length) continue;
      topMesh(`plate-${own}`, byTerritory[own], plateMat[own], 0, true);
      topMesh(`soil-${own}`, byTerritory[own], soilMat[own], 0.4, false);
    }
    {
      const positions: number[] = [], indices: number[] = [], owners: number[] = [];
      cells.forEach((c, i) => {
        const pts = tri(i);
        const v = positions.length / 3;
        for (const [px, pz] of pts) { positions.push(px, 0, pz); owners.push(i); }
        for (const [px, pz] of pts) { positions.push(px, -DEPTH, pz); owners.push(i); }
        indices.push(v + 3, v + 4, v + 5);
        for (let e = 0; e < 3; e += 1) {
          const a = v + e, b = v + ((e + 1) % 3);
          indices.push(a, b, b + 3, a, b + 3, a + 3);
        }
      });
      const mesh = new Mesh("sides", scene);
      const vd = new VertexData();
      vd.positions = positions; vd.indices = indices;
      vd.applyToMesh(mesh, true);
      mesh.material = sideMat;
      mesh.isPickable = false;
      batches.push({ mesh, base: Float32Array.from(positions), owners, lift: 0 });
    }

    // ---- line work: rim per territory, the mark's 135 edges (lit / fog),
    //      held outline; each line system remembers its island per vertex ---
    interface LineBatch { mesh: LinesMesh; base: Float32Array; owners: number[] }
    const lineBatches: LineBatch[] = [];
    const lineSystem = (name: string, idx: number[], segs: (i: number) => Vector3[][], color: string, alpha: number, lift: number) => {
      if (!idx.length) return;
      const lines: Vector3[][] = [];
      const owners: number[] = [];
      idx.forEach((i) => { for (const seg of segs(i)) { lines.push(seg.map((p) => new Vector3(p.x, lift, p.z))); for (let k = 0; k < seg.length; k += 1) owners.push(i); } });
      const mesh = CreateLineSystem(name, { lines, updatable: true }, scene);
      mesh.color = Color3.FromHexString(color);
      mesh.alpha = alpha;
      mesh.isPickable = false;
      lineBatches.push({ mesh, base: Float32Array.from(mesh.getVerticesData(VertexBuffer.PositionKind) ?? []), owners });
    };
    const outlineOf = (i: number) => { const p = tri(i); return [[new Vector3(p[0][0], 0, p[0][1]), new Vector3(p[1][0], 0, p[1][1]), new Vector3(p[2][0], 0, p[2][1]), new Vector3(p[0][0], 0, p[0][1])]]; };
    const edgesOf = (i: number) => { const c = cells[i]; return EDGES.map(([ax, ay, bx, by]) => [new Vector3(c.x + ax * S, 0, c.y + ay * S), new Vector3(c.x + bx * S, 0, c.y + by * S)]); };
    const lit = cells.map((_, i) => i).filter((i) => cells[i].own !== "fog");
    const fog = cells.map((_, i) => i).filter((i) => cells[i].own === "fog");
    lineSystem("rim-lit", lit, outlineOf, "#e8e8f0", 0.3, 0.6);
    lineSystem("rim-fog", fog, outlineOf, "#e8e8f0", 0.1, 0.6);
    lineSystem("walls-lit", lit, edgesOf, "#e8e8f0", 0.52, 0.7);
    lineSystem("walls-fog", fog, edgesOf, "#e8e8f0", 0.06, 0.7);
    lineSystem("held", byTerritory.held, outlineOf, "#00ff88", 0.55, 0.8);

    // picked (gold) and hover outlines
    const ring4 = () => [[new Vector3(0, 0, 0), new Vector3(0, 0, 0), new Vector3(0, 0, 0), new Vector3(0, 0, 0)]];
    const picked = CreateLineSystem("picked", { lines: ring4(), updatable: true }, scene);
    picked.color = Color3.FromHexString("#FFD45A"); picked.isPickable = false;
    const hovered = CreateLineSystem("hover", { lines: ring4(), updatable: true }, scene);
    hovered.color = Color3.FromHexString("#e8e8f0"); hovered.alpha = 0.6; hovered.isPickable = false;
    const placeRing = (mesh: LinesMesh, i: number, y: number) => {
      const p = tri(i); const pts = [p[0], p[1], p[2], p[0]];
      const buf = mesh.getVerticesData(VertexBuffer.PositionKind);
      if (!buf) return;
      pts.forEach(([px, pz], k) => { buf[k * 3] = px; buf[k * 3 + 1] = y; buf[k * 3 + 2] = pz; });
      mesh.updateVerticesData(VertexBuffer.PositionKind, buf);
      mesh.isVisible = true;
    };

    // ---- nodes: 27 glints per lit cell, pulsing (the canvas NODES pass) ----
    const sheet = glintSheet();
    const glints = new SpriteManager("glints", sheet.url, lit.length * NODES.length + 1, { width: sheet.cell, height: sheet.cell }, scene);
    glints.isPickable = false;
    interface Glint { sprite: Sprite; cell: number; vi: number; tier: number; ring: number; x: number; z: number }
    const glintList: Glint[] = [];
    lit.forEach((i) => {
      const c = cells[i];
      const tier = c.own === "held" ? 0 : 1;
      NODES.forEach((v, vi) => {
        const s = new Sprite("g", glints);
        s.cellIndex = tier * 3 + v.ring;
        s.width = 1; s.height = 1;
        s.position = new Vector3(c.x + v.x * S, 2, c.y + v.y * S);
        glintList.push({ sprite: s, cell: i, vi, tier, ring: v.ring, x: c.x + v.x * S, z: c.y + v.y * S });
      });
    });

    // ---- structures, crystals, the Queen, larvae, bees ---------------------
    const managers = new Map<string, SpriteManager>();
    const manager = (name: string, capacity: number) => {
      let m = managers.get(name);
      if (!m) {
        m = new SpriteManager(name, `./queen/${name}-256.png`, capacity, { width: 256, height: 256 }, scene);
        m.isPickable = false;
        managers.set(name, m);
      }
      return m;
    };
    interface Standing { sprite: Sprite; cell: number; lift: number }
    const standing: Standing[] = [];
    const put = (name: string, cell: number, size: number, lift: number, capacity = 200) => {
      const c = cells[cell];
      if (!c) return;
      const s = new Sprite(name, manager(name, capacity));
      s.width = size; s.height = size;
      s.position = new Vector3(c.x, lift + size / 2, c.y);
      standing.push({ sprite: s, cell, lift: lift + size / 2 });
    };
    cells.forEach((c, i) => {
      if (i === home) return;
      const card = cards[i];
      if (card) put(`structure-${card.column}`, i, S * 0.5, 0, 200);
    });
    put("queen", home, S * 0.9, 0, 1);
    const ring = cells
      .map((c, i) => ({ i, d: (c.x - cells[home].x) ** 2 + (c.y - cells[home].y) ** 2 }))
      .filter((e) => e.i !== home)
      .sort((a, b) => a.d - b.d);
    (devices ?? []).forEach((d, k) => { const r = ring[k]; if (r) put(`crystal-${crystalOf(d.family)}`, r.i, S * 0.45, 0, 64); });
    // ---- bees: one per worker slot. Busy bees and running cards come from
    //      two endpoints with no slot-to-issue link, so the pairing is
    //      positional (the k-th busy slot sits on the k-th running card); a
    //      busy bee with no card hovers at home, an idle bee is a larva on
    //      the ring around the Queen. The same rule and the same flight as
    //      the canvas comb. ------------------------------------------------
    const running = cells.map((c, i) => ({ c, i })).filter(({ i }) => cards[i]?.column === "running").map(({ i }) => i);
    const indexByNumber = new Map<number, number>();
    cells.forEach((c, i) => { if (c.cardNumber !== null) indexByNumber.set(c.cardNumber, i); });
    interface Bee { slot: number; busy: boolean; work: boolean; from: number; to: number; t: number; speed: number; hover: number; line: BeeLine; body: Sprite; larva: Sprite }
    const bees: Bee[] = (workers?.slots ?? []).map((slot, k) => {
      const line = LINES[k % LINES.length];
      const body = new Sprite(`bee-${slot.slot}`, manager(line, 16));
      const larva = new Sprite(`larva-${slot.slot}`, manager("larva", 16));
      body.width = S * 0.38 * 2 * 0.5; body.height = body.width; body.isVisible = false;
      larva.width = S * 0.35; larva.height = larva.width; larva.isVisible = false;
      return { slot: slot.slot, busy: false, work: false, from: home, to: home, t: 1, speed: 0, hover: k * 1.7, line, body, larva };
    });
    const ringCell = (rank: number) => { const r = ring[(devices?.length ?? 0) + rank]; return r ? r.i : home; };
    const aimBees = () => {
      const slots = new Map<number, "busy" | "idle">();
      for (const slot of workersRef.current?.slots ?? []) slots.set(slot.slot, slot.state);
      let busyRank = 0, idleRank = 0;
      for (const b of bees) {
        b.busy = slots.get(b.slot) === "busy";
        let target = home;
        if (b.busy) { target = running[busyRank] ?? home; b.work = running[busyRank] !== undefined; busyRank += 1; }
        else { b.work = false; target = ringCell(idleRank); idleRank += 1; }
        if (b.to !== target) { b.from = b.t < 0.5 ? b.from : b.to; b.to = target; b.t = 0; b.speed = b.busy ? 0.55 : 0.35; }
      }
    };
    aimBees();
    const beeAt = (index: number) => bees.find((b) => (b.t < 0.5 ? b.from : b.to) === index) ?? null;

    // ---- event glints: a ring that grows and fades on the issue's cell;
    //      a pool of line circles, one per live effect ----------------------
    interface Effect { index: number; tone: Tone; start: number; flip: boolean }
    const effects: Effect[] = [];
    const rings: LinesMesh[] = [];
    for (let k = 0; k < RING_POOL; k += 1) {
      const pts: Vector3[] = [];
      for (let a = 0; a <= 16; a += 1) pts.push(new Vector3(Math.cos((a / 16) * Math.PI * 2), 0, Math.sin((a / 16) * Math.PI * 2)));
      const m = CreateLineSystem(`fx-${k}`, { lines: [pts], updatable: false }, scene);
      m.isPickable = false; m.isVisible = false;
      rings.push(m);
    }
    let lastEvents: HudEvent[] | null = null;
    const ingestEvents = (stamp: number) => {
      const list = eventsRef.current;
      if (list === lastEvents) return;
      lastEvents = list;
      const seen = seenEventsRef.current;
      const primed = eventsPrimedRef.current;
      const wall = Date.now();
      for (const event of list) {
        if (seen.has(event.id)) continue;
        seen.add(event.id);
        if (!primed && wall - new Date(event.at).getTime() > 30_000) continue;
        const index = event.issue !== null ? indexByNumber.get(event.issue) : undefined;
        if (index === undefined) continue;
        effects.push({ index, tone: eventTone(event.kind), start: stamp, flip: false });
      }
      eventsPrimedRef.current = true;
      if (seen.size > 2000) seenEventsRef.current = new Set(list.map((event) => event.id));
    };

    // ---- picking and hover ---------------------------------------------------
    const cellUnder = (x: number, y: number) => {
      const hit = scene.pick(x, y, (m) => m.isPickable);
      if (!hit?.hit || !hit.pickedPoint) return -1;
      return cellAtWorld(cells, hit.pickedPoint.x, hit.pickedPoint.z);
    };
    let hover = -1;
    let downAt: [number, number] | null = null;
    let travelled = 0;
    scene.onPointerObservable.add((info) => {
      if (info.type === PointerEventTypes.POINTERDOWN) { downAt = [scene.pointerX, scene.pointerY]; travelled = 0; }
      if (info.type === PointerEventTypes.POINTERMOVE) {
        if (downAt) { travelled += Math.abs(scene.pointerX - downAt[0]) + Math.abs(scene.pointerY - downAt[1]); downAt = [scene.pointerX, scene.pointerY]; }
        else hover = cellUnder(scene.pointerX, scene.pointerY);
      }
      if (info.type === PointerEventTypes.POINTERUP) downAt = null;
    });
    // The pick is the click, as in the canvas comb: a drag (travelled > 6 px
    // between pointerdown and pointerup) never picks; a tap or a synthetic
    // click does. Coordinates are the event's own, so a contract's dispatched
    // MouseEvent lands where it says.
    canvas.addEventListener("click", (e) => {
      if (travelled > 6) { travelled = 0; return; }
      const rect = canvas.getBoundingClientRect();
      const index = cellUnder(e.clientX - rect.left, e.clientY - rect.top);
      if (index < 0) return;
      const card = cards[index];
      const b = beeAt(index);
      onPickRef.current?.({ index, isQueen: index === home, territory: cells[index].own, card: card ?? null, bee: b ? { slot: b.slot, line: b.line, busy: b.busy } : null } as HudPick);
    });
    canvas.addEventListener("pointerleave", () => { hover = -1; });

    // ---- frame loop ---------------------------------------------------------
    const t0 = performance.now();
    let frames = 0;
    let lastMs = t0;
    engine.runRenderLoop(() => {
      const t = (performance.now() - t0) / 1000;
      if (insetRef.current !== appliedInset) fit();
      if (!manual) camera.alpha = Math.PI / 2 + Math.sin(t / 9) * 0.35;
      for (const b of batches) {
        const pos = b.mesh.getVerticesData(VertexBuffer.PositionKind);
        if (!pos) continue;
        for (let v = 0; v < b.owners.length; v += 1) pos[v * 3 + 1] = b.base[v * 3 + 1] + bob(b.owners[v], t);
        b.mesh.updateVerticesData(VertexBuffer.PositionKind, pos);
      }
      for (const b of lineBatches) {
        const pos = b.mesh.getVerticesData(VertexBuffer.PositionKind);
        if (!pos) continue;
        for (let v = 0; v < b.owners.length; v += 1) pos[v * 3 + 1] = b.base[v * 3 + 1] + bob(b.owners[v], t);
        b.mesh.updateVerticesData(VertexBuffer.PositionKind, pos);
      }
      for (const g of glintList) {
        const pulse = 0.55 + 0.45 * Math.sin(t * 1.6 + phase(g.cell) + g.vi * 0.21);
        const size = (g.tier === 0 ? 7 : 5) * (0.75 + 0.5 * pulse) * 0.5;
        g.sprite.width = size; g.sprite.height = size;
        g.sprite.position.y = bob(g.cell, t) + 2;
        const bright = pulse > 0.78 ? 2 : pulse > 0.5 ? 1 : 0;
        g.sprite.color.a = [0.3, 0.58, 0.9][g.tier === 0 ? bright : Math.min(bright, 1)];
      }
      for (const s of standing) s.sprite.position.y = s.lift + bob(s.cell, t);
      // bees
      const nowMs = performance.now();
      const dt = Math.min(nowMs - lastMs, 32); lastMs = nowMs;
      aimBees();
      for (const b of bees) {
        if (b.t < 1) b.t = Math.min(1, b.t + (b.speed * dt) / 1000);
        const A = cells[b.from], B = cells[b.to];
        if (!A || !B) continue;
        const e = b.t < 0.5 ? 2 * b.t * b.t : 1 - 2 * (1 - b.t) * (1 - b.t);
        let x = A.x + (B.x - A.x) * e, z = A.y + (B.y - A.y) * e;
        let arc = b.busy ? Math.sin(Math.PI * b.t) * 46 : 2;
        if (b.t >= 1 && b.busy) { const ph = nowMs / 700 + b.hover; x = B.x + Math.cos(ph) * S * 0.14; z = B.y + Math.sin(ph * 1.3) * S * 0.08; arc = 18 + Math.sin(ph * 2) * 5; }
        const sprite = b.busy ? b.body : b.larva;
        b.body.isVisible = b.busy; b.larva.isVisible = !b.busy;
        sprite.position.x = x; sprite.position.z = z;
        sprite.position.y = bob(b.to, t) + arc + sprite.height / 2 + (b.busy ? Math.sin(nowMs / 90 + b.from) * sprite.height * 0.04 : 0);
        sprite.invertU = B.x - A.x < 0;
      }
      // effects
      ingestEvents(nowMs);
      let write = 0;
      for (let i = 0; i < effects.length; i += 1) {
        const fx = effects[i]; const cell = cells[fx.index]; const life = fx.flip ? 900 : 1300; const age = nowMs - fx.start;
        if (!cell || age > life) continue;
        effects[write] = fx; write += 1;
      }
      effects.length = Math.min(write, RING_POOL);
      for (let k = 0; k < RING_POOL; k += 1) {
        const fx = effects[k]; const ring = rings[k];
        if (!fx) { ring.isVisible = false; continue; }
        const cell = cells[fx.index]; const u = (nowMs - fx.start) / (fx.flip ? 900 : 1300);
        const r = S * (0.12 + 0.5 * u);
        ring.position.set(cell.x, bob(fx.index, t) + 1.5, cell.y);
        ring.scaling.set(r, 1, r);
        ring.color = Color3.FromHexString(TONE_HEX[fx.tone]);
        ring.alpha = 0.9 * (1 - u);
        ring.isVisible = true;
      }
      const p = pickRef.current;
      if (p !== null && cells[p]) placeRing(picked, p, bob(p, t) + 1); else picked.isVisible = false;
      if (hover >= 0 && hover !== p && cells[hover]) placeRing(hovered, hover, bob(hover, t) + 1); else hovered.isVisible = false;
      scene.render();
      frames += 1;
      if (frames === 1) host.setAttribute("data-first-frame-ms", String(Math.round(performance.now() - t0)));
      host.setAttribute("data-frames", String(frames));
    });
    const ro = new ResizeObserver(() => { engine.resize(); fit(); });
    ro.observe(host);
    return () => { ro.disconnect(); engine.stopRenderLoop(); scene.dispose(); engine.dispose(); };
  }, [signature]);

  return (
    <div className="queen27-comb is-embedded is-babylon">
      <div className="queen27-comb-field" ref={hostRef} data-engine="babylon">
        <canvas ref={canvasRef} style={{ touchAction: "none", outline: "none" }} />
      </div>
    </div>
  );
}
