// The comb in Babylon.js as a GAME FIELD (the user, 2026-09-04 11:10Z, with a
// StarCraft screenshot: "I want a field like THIS"): one continuous plate of
// steel tiles with the mark engraved in every tile, low-poly buildings with
// volume standing where the cards stand, bees as units on the ground, an RTS
// camera (fixed angle, zoom, no idle sway). The cells still come from
// summariseCells, so placement, picking, the pairing of bees to running cards
// and the event glints keep their rules; only the picture changed. Buildings
// are procedural until the user names an asset pack (B-5).
import { useEffect, useRef } from "react";
import { Engine } from "@babylonjs/core/Engines/engine";
import { Scene } from "@babylonjs/core/scene";
import { ArcRotateCamera } from "@babylonjs/core/Cameras/arcRotateCamera";
import { Camera } from "@babylonjs/core/Cameras/camera";
import { Vector3, Matrix } from "@babylonjs/core/Maths/math.vector";
import { Color3, Color4 } from "@babylonjs/core/Maths/math.color";
import { Mesh } from "@babylonjs/core/Meshes/mesh";
import { VertexBuffer } from "@babylonjs/core/Buffers/buffer";
import { StandardMaterial } from "@babylonjs/core/Materials/standardMaterial";
import { DynamicTexture } from "@babylonjs/core/Materials/Textures/dynamicTexture";
import { SpriteManager } from "@babylonjs/core/Sprites/spriteManager";
import { Sprite } from "@babylonjs/core/Sprites/sprite";
import { CreateLineSystem, CreateDashedLines } from "@babylonjs/core/Meshes/Builders/linesBuilder";
import { CreateGround } from "@babylonjs/core/Meshes/Builders/groundBuilder";
import { CreateBox } from "@babylonjs/core/Meshes/Builders/boxBuilder";
import { CreateCylinder } from "@babylonjs/core/Meshes/Builders/cylinderBuilder";
import { CreateSphere } from "@babylonjs/core/Meshes/Builders/sphereBuilder";
import { CreateTorus } from "@babylonjs/core/Meshes/Builders/torusBuilder";
import { HemisphericLight } from "@babylonjs/core/Lights/hemisphericLight";
import { DirectionalLight } from "@babylonjs/core/Lights/directionalLight";
import { ShadowGenerator } from "@babylonjs/core/Lights/Shadows/shadowGenerator";
import "@babylonjs/core/Lights/Shadows/shadowGeneratorSceneComponent";
import "@babylonjs/core/Meshes/thinInstanceMesh";
import type { LinesMesh } from "@babylonjs/core/Meshes/linesMesh";
import { PointerEventTypes } from "@babylonjs/core/Events/pointerEvents";
import "@babylonjs/core/Culling/ray";
import { S, HH, EDGES, summariseCells, queenIndexOf } from "./QueenComb";
import { crystalOf, eventTone, ringTone, type BeeLine, type HudEvent, type HudPick, type Tone } from "./queenHud";

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

type Territory = "held" | "neutral" | "fog";
const LINES: readonly BeeLine[] = ["scribe", "wright", "lapidary"];
const TONE_HEX: Record<Tone, string> = { gold: "#FFD45A", cold: "#FF6B6B", green: "#00FF88", cyan: "#64DCFF", muted: "#FFFFFF" };
const EMPTY_EVENTS: HudEvent[] = [];
const RING_POOL = 24;
const COLUMNS = ["backlog", "running", "review", "done", "blocked", "dropped"] as const;
type Column = (typeof COLUMNS)[number];
const MARGIN = S * 1.2;

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

/**
 * The ground: steel platform tiles (the user's StarCraft reference), panel
 * seams, corner bolts, and the mark engraved faintly in the centre of every
 * tile - "the tile IS our drawing" survives as an engraving.
 */
function drawTiles(ctx: CanvasRenderingContext2D, size: number, per: number) {
  const tile = size / per;
  ctx.fillStyle = "#4d5563";
  ctx.fillRect(0, 0, size, size);
  for (let r = 0; r < per; r += 1) for (let c = 0; c < per; c += 1) {
    const x = c * tile, y = r * tile;
    const v = ((r * 7 + c * 13) % 5) - 2;
    ctx.fillStyle = `rgb(${86 + v * 3},${94 + v * 3},${108 + v * 3})`;
    ctx.fillRect(x + 2, y + 2, tile - 4, tile - 4);
    ctx.strokeStyle = "rgba(20,24,32,.9)";
    ctx.lineWidth = 3;
    ctx.strokeRect(x + 1.5, y + 1.5, tile - 3, tile - 3);
    ctx.strokeStyle = "rgba(160,170,190,.25)";
    ctx.lineWidth = 1;
    ctx.strokeRect(x + 5.5, y + 5.5, tile - 11, tile - 11);
    ctx.fillStyle = "rgba(20,24,32,.8)";
    for (const [bx, by] of [[9, 9], [tile - 9, 9], [9, tile - 9], [tile - 9, tile - 9]]) { ctx.beginPath(); ctx.arc(x + bx, y + by, 2.2, 0, Math.PI * 2); ctx.fill(); }
    ctx.strokeStyle = "rgba(200,210,230,.16)";
    ctx.lineWidth = 1;
    ctx.beginPath();
    const sc = tile * 0.62, cx = x + tile / 2, cy = y + tile / 2;
    for (const [ax, ay, bx2, by2] of EDGES) { ctx.moveTo(cx + ax * sc, cy + ay * sc); ctx.lineTo(cx + bx2 * sc, cy + by2 * sc); }
    ctx.stroke();
  }
}

export function QueenCombBabylon({ cards, workers, devices, onPick, pickIndex = null, fitInset = 0, events = EMPTY_EVENTS }: QueenCombBabylonProps) {
  const hostRef = useRef<HTMLDivElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const onPickRef = useRef(onPick);
  const pickRef = useRef<number | null>(pickIndex);
  const insetRef = useRef(fitInset);
  const eventsRef = useRef(events);
  const seenEventsRef = useRef<Set<string>>(new Set());
  const eventsPrimedRef = useRef(false);
  useEffect(() => {
    onPickRef.current = onPick;
    pickRef.current = pickIndex;
    insetRef.current = fitInset;
    eventsRef.current = events;
  }, [onPick, pickIndex, fitInset, events]);

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

    // ---- extents and the RTS camera: fixed angle, zoom, no idle sway ------
    let minX = Infinity, maxX = -Infinity, minZ = Infinity, maxZ = -Infinity;
    for (const c of cells) {
      minX = Math.min(minX, c.x - S / 2); maxX = Math.max(maxX, c.x + S / 2);
      minZ = Math.min(minZ, c.yTop); maxZ = Math.max(maxZ, c.yTop + HH);
    }
    const centre = new Vector3((minX + maxX) / 2, 0, (minZ + maxZ) / 2);
    const camera = new ArcRotateCamera("cam", Math.PI / 2 + 0.55, 0.95, 4000, centre.clone(), scene);
    camera.mode = Camera.ORTHOGRAPHIC_CAMERA;
    camera.lowerBetaLimit = 0.95; camera.upperBetaLimit = 0.95;
    camera.lowerAlphaLimit = camera.alpha; camera.upperAlphaLimit = camera.alpha;
    camera.panningSensibility = 0;
    let zoom = 1;
    let appliedInset = -1;
    const fit = () => {
      const w = host.clientWidth || 1, h = host.clientHeight || 1;
      const inset = insetRef.current;
      const band = h * (1 - inset);
      const fieldW = (maxX - minX + S) * 1.02, fieldH = (maxZ - minZ + S) * Math.cos(camera.beta) * 1.02 + S * 0.6;
      const aspect = w / band;
      let halfW = fieldW / 2, halfH = halfW / aspect;
      if (halfH < fieldH / 2) { halfH = fieldH / 2; halfW = halfH * aspect; }
      halfW /= zoom; halfH /= zoom;
      const unitsPerPx = (halfH * 2) / band;
      const shift = (h - band) * unitsPerPx;
      camera.orthoLeft = -halfW; camera.orthoRight = halfW;
      camera.orthoTop = halfH; camera.orthoBottom = -halfH - shift;
      appliedInset = inset;
    };
    fit();
    canvas.addEventListener("wheel", (e) => { e.preventDefault(); zoom = Math.min(8, Math.max(0.5, zoom * (e.deltaY < 0 ? 1.1 : 1 / 1.1))); fit(); }, { passive: false });

    // ---- light: a sun from the upper left and a soft sky, shadows on -----
    const sky = new HemisphericLight("sky", new Vector3(0.2, 1, 0.1), scene);
    sky.intensity = 0.55;
    sky.groundColor = new Color3(0.12, 0.14, 0.18);
    const sun = new DirectionalLight("sun", new Vector3(-0.6, -1, 0.35), scene);
    sun.intensity = 1.1;
    sun.position = new Vector3(centre.x + 800, 1400, centre.z - 500);
    const shadows = new ShadowGenerator(2048, sun);
    shadows.useBlurExponentialShadowMap = true;
    shadows.blurKernel = 16;
    shadows.darkness = 0.45;

    // ---- the ground: one plate of steel tiles ----------------------------
    const tex = new DynamicTexture("tiles", 1024, scene, true);
    const tctx = tex.getContext() as CanvasRenderingContext2D;
    drawTiles(tctx, 1024, 8);
    tex.update(false);
    const groundW = maxX - minX + MARGIN * 2, groundH = maxZ - minZ + MARGIN * 2;
    tex.uScale = groundW / (S * 0.5 * 8);
    tex.vScale = groundH / (S * 0.5 * 8);
    const groundMat = new StandardMaterial("ground", scene);
    groundMat.diffuseTexture = tex;
    groundMat.specularColor = new Color3(0.08, 0.08, 0.1);
    const ground = CreateGround("ground", { width: groundW, height: groundH }, scene);
    ground.position = new Vector3(centre.x, 0, centre.z);
    ground.material = groundMat;
    ground.receiveShadows = true;
    ground.isPickable = true;
    const rim = CreateBox("rim", { width: groundW + 8, depth: groundH + 8, height: 14 }, scene);
    rim.position = new Vector3(centre.x, -7.5, centre.z);
    const rimMat = new StandardMaterial("rim", scene);
    rimMat.diffuseColor = new Color3(0.08, 0.09, 0.12);
    rim.material = rimMat;
    rim.isPickable = false;

    // ---- buildings: one low-poly template per column, thin-instanced ------
    const mat = (name: string, diffuse: string, emissive = "#000000") => {
      const m = new StandardMaterial(name, scene);
      m.diffuseColor = Color3.FromHexString(diffuse);
      m.emissiveColor = Color3.FromHexString(emissive);
      m.specularColor = new Color3(0.15, 0.15, 0.18);
      return m;
    };
    const steel = mat("steel", "#8a93a3"), dark = mat("dark", "#3a4150"), glass = mat("glass", "#1d3a4a", "#0e5a7a");
    const green = mat("green", "#1e4d3a", "#00ff88"), gold = mat("gold", "#5a4a1e", "#ffd45a"), red = mat("red", "#4d1e1e", "#ff6b6b"), cyan = mat("cyan", "#1e3f4d", "#64dcff"), ruin = mat("ruin", "#2a2d33");
    const u = S * 0.5;
    interface Template { parts: Mesh[]; matrices: number[] }
    const templates: Record<Column, Template> = {} as Record<Column, Template>;
    const part = (m: Mesh, material: StandardMaterial, y: number, x = 0, z = 0) => { m.material = material; m.position.set(x, y, z); m.isPickable = false; m.isVisible = false; shadows.addShadowCaster(m); return m; };
    templates.backlog = { parts: [
      part(CreateBox("bl-slab", { width: u, depth: u, height: 5 }, scene), dark, 2.5),
      ...[[-1, -1], [1, -1], [-1, 1], [1, 1]].map(([px, pz], k) => part(CreateBox(`bl-post-${k}`, { width: 4, depth: 4, height: 16 }, scene), steel, 8, px * u * 0.42, pz * u * 0.42)),
    ], matrices: [] };
    templates.running = { parts: [
      part(CreateBox("ru-body", { width: u * 0.8, depth: u * 0.8, height: u * 0.55 }, scene), steel, u * 0.275),
      part(CreateBox("ru-band", { width: u * 0.84, depth: u * 0.84, height: 4 }, scene), cyan, u * 0.3),
      part(CreateCylinder("ru-mast", { diameter: 3, height: u * 0.6 }, scene), steel, u * 0.85, u * 0.25, u * 0.25),
      part(CreateSphere("ru-lamp", { diameter: 8 }, scene), cyan, u * 1.15, u * 0.25, u * 0.25),
    ], matrices: [] };
    templates.review = { parts: [
      part(CreateCylinder("rv-base", { diameter: u * 0.9, height: u * 0.3, tessellation: 12 }, scene), steel, u * 0.15),
      part(CreateSphere("rv-dome", { diameter: u * 0.7, slice: 0.5, segments: 12 }, scene), glass, u * 0.3),
      part(CreateTorus("rv-ring", { diameter: u * 0.72, thickness: 3, tessellation: 24 }, scene), gold, u * 0.31),
    ], matrices: [] };
    templates.done = { parts: [
      part(CreateBox("dn-tower", { width: u * 0.6, depth: u * 0.6, height: u * 1.1 }, scene), steel, u * 0.55),
      part(CreateBox("dn-win1", { width: u * 0.62, depth: u * 0.62, height: 3 }, scene), green, u * 0.35),
      part(CreateBox("dn-win2", { width: u * 0.62, depth: u * 0.62, height: 3 }, scene), green, u * 0.7),
      part(CreateBox("dn-cap", { width: u * 0.7, depth: u * 0.7, height: 6 }, scene), dark, u * 1.13),
    ], matrices: [] };
    templates.blocked = { parts: [
      part(CreateBox("bk-body", { width: u * 0.7, depth: u * 0.7, height: u * 0.4 }, scene), dark, u * 0.2),
      part(CreateTorus("bk-fence", { diameter: u * 0.95, thickness: 2.5, tessellation: 6 }, scene), red, 8),
      part(CreateBox("bk-light", { width: u * 0.72, depth: u * 0.72, height: 3 }, scene), red, u * 0.42),
    ], matrices: [] };
    templates.dropped = { parts: [
      part(CreateBox("dr-a", { width: u * 0.5, depth: u * 0.4, height: u * 0.18 }, scene), ruin, u * 0.09, -u * 0.12, u * 0.05),
      part(CreateBox("dr-b", { width: u * 0.3, depth: u * 0.3, height: u * 0.3 }, scene), ruin, u * 0.15, u * 0.2, -u * 0.15),
    ], matrices: [] };
    cells.forEach((c, i) => {
      if (i === home) return;
      const card = cards[i];
      if (!card) return;
      const col = (COLUMNS as readonly string[]).includes(card.column) ? (card.column as Column) : "backlog";
      templates[col].matrices.push(...Matrix.Translation(c.x, 0, c.y).toArray());
    });
    for (const col of COLUMNS) {
      const t = templates[col];
      const count = t.matrices.length / 16;
      for (const p of t.parts) {
        if (count === 0) { p.dispose(); continue; }
        p.isVisible = true;
        p.thinInstanceSetBuffer("matrix", new Float32Array(t.matrices), 16, true);
      }
    }
    const hub = part(CreateCylinder("hub", { diameter: S * 0.9, height: 10, tessellation: 24 }, scene), steel, 5, cells[home].x, cells[home].y);
    hub.isVisible = true;
    const hubDome = part(CreateSphere("hub-dome", { diameter: S * 0.5, slice: 0.5, segments: 16 }, scene), gold, 10, cells[home].x, cells[home].y);
    hubDome.isVisible = true;

    // ---- rings: picked (gold), hover (dashed, territory colour) ---------
    const ring4 = () => [[new Vector3(0, 0, 0), new Vector3(0, 0, 0), new Vector3(0, 0, 0), new Vector3(0, 0, 0)]];
    const picked = CreateLineSystem("picked", { lines: ring4(), updatable: true }, scene);
    picked.color = Color3.FromHexString("#FFD45A"); picked.isPickable = false;
    const tri = (i: number): [number, number][] => { const c = cells[i]; return [[c.x - S / 2, c.yTop], [c.x + S / 2, c.yTop], [c.x, c.yTop + HH]]; };
    const placeRing = (mesh: LinesMesh, i: number, y: number) => {
      const p = tri(i); const pts = [p[0], p[1], p[2], p[0]];
      const buf = mesh.getVerticesData(VertexBuffer.PositionKind);
      if (!buf) return;
      pts.forEach(([px, pz], k) => { buf[k * 3] = px; buf[k * 3 + 1] = y; buf[k * 3 + 2] = pz; });
      mesh.updateVerticesData(VertexBuffer.PositionKind, buf);
      mesh.isVisible = true;
    };
    const hovered = CreateDashedLines("hover", { points: [new Vector3(0, 0, 0), new Vector3(1, 0, 0), new Vector3(1, 0, 1), new Vector3(0, 0, 0)], dashSize: 3, gapSize: 2, dashNb: 60, updatable: true }, scene);
    hovered.alpha = 0.8; hovered.isPickable = false; hovered.isVisible = false;
    const placeDashed = (i: number, y: number) => {
      const p = tri(i);
      CreateDashedLines("hover", { points: [new Vector3(p[0][0], y, p[0][1]), new Vector3(p[1][0], y, p[1][1]), new Vector3(p[2][0], y, p[2][1]), new Vector3(p[0][0], y, p[0][1])], dashSize: 3, gapSize: 2, dashNb: 60, instance: hovered }, scene);
      hovered.color = Color3.FromHexString(ringTone(cells[i].own as Territory));
      hovered.isVisible = true;
    };

    // ---- sprites: the Queen's portrait, crystals, bees as units ----------
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
    const put = (name: string, cell: number, size: number, lift: number, capacity = 64) => {
      const c = cells[cell];
      if (!c) return null;
      const s = new Sprite(name, manager(name, capacity));
      s.width = size; s.height = size;
      s.position = new Vector3(c.x, lift + size / 2, c.y);
      return s;
    };
    put("queen", home, S * 0.6, S * 0.28, 1);
    const ring = cells
      .map((c, i) => ({ i, d: (c.x - cells[home].x) ** 2 + (c.y - cells[home].y) ** 2 }))
      .filter((e) => e.i !== home)
      .sort((a, b) => a.d - b.d);
    (devices ?? []).forEach((d, k) => { const r = ring[k]; if (r) put(`crystal-${crystalOf(d.family)}`, r.i, S * 0.4, 0, 64); });

    const running = cells.map((c, i) => ({ c, i })).filter(({ i }) => cards[i]?.column === "running").map(({ i }) => i);
    const indexByNumber = new Map<number, number>();
    cells.forEach((c, i) => { if (c.cardNumber !== null) indexByNumber.set(c.cardNumber, i); });
    interface Bee { slot: number; busy: boolean; work: boolean; from: number; to: number; t: number; speed: number; hover: number; line: BeeLine; body: Sprite; larva: Sprite }
    const bees: Bee[] = (workers?.slots ?? []).map((slot, k) => {
      const line = LINES[k % LINES.length];
      const body = new Sprite(`bee-${slot.slot}`, manager(line, 16));
      const larva = new Sprite(`larva-${slot.slot}`, manager("larva", 16));
      body.width = S * 0.34; body.height = body.width; body.isVisible = false;
      larva.width = S * 0.3; larva.height = larva.width; larva.isVisible = false;
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
    const flightLines = bees.map((b) => { const m = CreateDashedLines(`flight-${b.slot}`, { points: [new Vector3(0, 0, 0), new Vector3(1, 0, 1)], dashSize: 6, gapSize: 4, dashNb: 40, updatable: true }, scene); m.color = Color3.FromHexString("#64DCFF"); m.alpha = 0.55; m.isPickable = false; m.isVisible = false; return m; });
    const unitRings = bees.map((b) => { const m = CreateTorus(`unit-ring-${b.slot}`, { diameter: S * 0.26, thickness: 1.6, tessellation: 20 }, scene); m.material = green; m.isPickable = false; m.isVisible = false; return m; });

    // ---- event glints: a ring that grows and fades on the issue's cell ----
    interface Effect { index: number; tone: Tone; start: number; flip: boolean; flare?: string }
    let flaredPick: number | null = null;
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
      const hit = scene.pick(x, y, (m) => m === ground);
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
      const nowMs = performance.now();
      const dt = Math.min(nowMs - lastMs, 32); lastMs = nowMs;
      if (insetRef.current !== appliedInset) fit();
      aimBees();
      bees.forEach((b, k) => {
        if (b.t < 1) b.t = Math.min(1, b.t + (b.speed * dt) / 1000);
        const A = cells[b.from], B = cells[b.to];
        if (!A || !B) return;
        const e = b.t < 0.5 ? 2 * b.t * b.t : 1 - 2 * (1 - b.t) * (1 - b.t);
        let x = A.x + (B.x - A.x) * e, z = A.y + (B.y - A.y) * e;
        if (b.t >= 1 && b.busy) { const ph = nowMs / 700 + b.hover; x = B.x + Math.cos(ph) * S * 0.12; z = B.y + Math.sin(ph * 1.3) * S * 0.08; }
        const sprite = b.busy ? b.body : b.larva;
        b.body.isVisible = b.busy; b.larva.isVisible = !b.busy;
        sprite.position.x = x; sprite.position.z = z;
        sprite.position.y = sprite.height / 2 + (b.busy ? 2 + Math.abs(Math.sin(nowMs / 140 + k)) * 3 : 1);
        sprite.invertU = B.x - A.x < 0;
        const ur = unitRings[k]; ur.position.set(x, 1.2, z); ur.isVisible = true;
        const line = flightLines[k];
        if (b.busy && b.t < 1) { CreateDashedLines(`flight-${b.slot}`, { points: [new Vector3(A.x, 2, A.y), new Vector3(B.x, 2, B.y)], dashSize: 6, gapSize: 4, dashNb: 40, instance: line }, scene); line.isVisible = true; }
        else line.isVisible = false;
      });
      ingestEvents(nowMs);
      let write = 0;
      for (let i = 0; i < effects.length; i += 1) {
        const fx = effects[i]; const cell = cells[fx.index]; const life = fx.flare ? 500 : fx.flip ? 900 : 1300; const age = nowMs - fx.start;
        if (!cell || age > life) continue;
        effects[write] = fx; write += 1;
      }
      effects.length = Math.min(write, RING_POOL);
      for (let k = 0; k < RING_POOL; k += 1) {
        const fx = effects[k]; const ring = rings[k];
        if (!fx) { ring.isVisible = false; continue; }
        const cell = cells[fx.index]; const life = fx.flare ? 500 : fx.flip ? 900 : 1300; const u2 = (nowMs - fx.start) / life;
        const r = fx.flare ? S * (0.9 - 0.6 * u2) : S * (0.12 + 0.5 * u2);
        ring.position.set(cell.x, 1.5, cell.y);
        ring.scaling.set(r, 1, r);
        ring.color = Color3.FromHexString(fx.flare ?? TONE_HEX[fx.tone]);
        ring.alpha = 0.9 * (1 - u2);
        ring.isVisible = true;
      }
      const p = pickRef.current;
      if (p !== null && cells[p]) placeRing(picked, p, 1.4); else picked.isVisible = false;
      if (p !== flaredPick) { flaredPick = p; if (p !== null && cells[p] && effects.length < RING_POOL) effects.push({ index: p, tone: "muted", start: nowMs, flip: false, flare: ringTone(cells[p].own as Territory) }); }
      if (hover >= 0 && hover !== p && cells[hover]) placeDashed(hover, 1.4); else hovered.isVisible = false;
      scene.render();
      frames += 1;
      if (frames === 1) host.setAttribute("data-first-frame-ms", String(Math.round(nowMs - t0)));
      host.setAttribute("data-frames", String(frames));
    });
    const ro = new ResizeObserver(() => { engine.resize(); fit(); });
    ro.observe(host);
    return () => { ro.disconnect(); engine.stopRenderLoop(); scene.dispose(); engine.dispose(); };
  }, [signature]);

  return (
    <div className="queen27-comb is-embedded is-babylon">
      <div className="queen27-comb-field" ref={hostRef} data-engine="babylon" data-look="platform">
        <canvas ref={canvasRef} style={{ touchAction: "none", outline: "none" }} />
      </div>
    </div>
  );
}
