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
import { Vector3, Matrix, Quaternion } from "@babylonjs/core/Maths/math.vector";
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
import { GlowLayer } from "@babylonjs/core/Layers/glowLayer";
import "@babylonjs/core/Layers/effectLayerSceneComponent";
import "@babylonjs/core/Meshes/thinInstanceMesh";
import { LoadAssetContainerAsync } from "@babylonjs/core/Loading/sceneLoader";
import "@babylonjs/loaders/glTF";
import type { AbstractMesh } from "@babylonjs/core/Meshes/abstractMesh";
import type { PBRMaterial } from "@babylonjs/core/Materials/PBR/pbrMaterial";
import type { BaseTexture } from "@babylonjs/core/Materials/Textures/baseTexture";
import type { InstancedMesh } from "@babylonjs/core/Meshes/instancedMesh";
import type { LinesMesh } from "@babylonjs/core/Meshes/linesMesh";
import { PointerEventTypes } from "@babylonjs/core/Events/pointerEvents";
import "@babylonjs/core/Culling/ray";
import { S, EDGES } from "./QueenComb";
import { buildingPlan, buildingTint, crystalOf, eventTone, ringTone, type BeeLine, type HudEvent, type HudModule, type HudPick, type Tone , eventIdentity , hexCellSummaries, hexIndexAt, hexCornersAt, HEX_HOME, HEX_R } from "./queenHud";

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
  /** The code modules by card id (M-2): the building is generated from the signature. */
  modules?: ReadonlyMap<number, HudModule>;
  /** Per issue in progress: the cell of the module its title names, or null (the hub). */
  beeTargets?: ReadonlyArray<number | null>;
}
// the plan's part kinds map to models the field loads: annexes are the
// platform, antennae the dish; the core is the plan's own key
const PART_MODEL: Record<"annex" | "antenna", ModelKey> = { annex: "backlog", antenna: "review" };

type Territory = "held" | "neutral" | "fog";
const LINES: readonly BeeLine[] = ["scribe", "wright", "lapidary"];
const TONE_HEX: Record<Tone, string> = { gold: "#FFD45A", cold: "#FF6B6B", green: "#00FF88", cyan: "#64DCFF", muted: "#FFFFFF" };
const EMPTY_EVENTS: HudEvent[] = [];
const RING_POOL = 24;
const COLUMNS = ["backlog", "running", "review", "done", "blocked", "dropped"] as const;
type Column = (typeof COLUMNS)[number];
// Kenney Space Kit (CC0, kenney.nl), the user's "download it yourself, open
// source": one model per building state, three for done cards, the Queen's
// hangar, crystals, and units. Served from public/queen/models.
const MODELS = {
  backlog: "platform_small", running: "machine_generatorLarge", review: "satelliteDish_large",
  done: "hangar_smallA", doneDepot: "hangar_roundA", doneSilo: "structure_closed",
  blocked: "gate_complex", dropped: "crater", hub: "hangar_largeA", crystal: "rock_crystalsLargeA",
  scribe: "astronautA", wright: "rover", lapidary: "astronautB", larva: "alien",
} as const;
type ModelKey = keyof typeof MODELS;
const MARGIN = S * 1.2;

/** Point-in-down-triangle for the cell under a world point (x, z). */

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

/**
 * Load a Kenney GLB and merge it into one mesh with a multi-material, so it
 * can be thin-instanced like the procedural templates. Returns the mesh and
 * its footprint (max of width and depth) and base (min y), both in model
 * units, so the caller can scale it to a cell and stand it on the ground.
 */
async function loadTemplate(scene: Scene, key: ModelKey): Promise<{ mesh: Mesh; footprint: number; base: number; height: number } | null> {
  try {
    if (scene.isDisposed) return null;
    const container = await LoadAssetContainerAsync(`./queen/models/${MODELS[key]}.glb`, scene);
    // the view may have switched while the file was in flight: a disposed
    // scene has no engine program to compile materials on
    if (scene.isDisposed) { container.dispose(); return null; }
    const parts = container.meshes.filter((m): m is Mesh => m instanceof Mesh && m.getTotalVertices() > 0);
    if (parts.length === 0) return null;
    // Kenney's models are flat palette colours: a StandardMaterial carries
    // them as well as the glTF PBR one, lights like the rest of the field,
    // and needs no BRDF lookup texture - the async generation of that texture
    // ran its callback on a disposed engine when the view switched mid-load
    // (TypeError: reading 'program' in bindSamplers), which the viewport gate
    // counted as a failure.
    for (const m of parts) {
      const src = m.material as (PBRMaterial & { albedoTexture?: BaseTexture | null; albedoColor?: Color3 }) | null;
      if (src && src.getClassName() === "PBRMaterial") {
        const flat = new StandardMaterial(`${src.name}-flat`, scene);
        if (src.albedoTexture) flat.diffuseTexture = src.albedoTexture;
        if (src.albedoColor) flat.diffuseColor = src.albedoColor.clone();
        flat.specularColor = new Color3(0.12, 0.12, 0.14);
        flat.specularPower = 32;
        m.material = flat;
        src.dispose(false, false);
      }
    }
    // bake the glTF root transform (right-handed -> left-handed flip) into the vertices
    for (const m of parts) { m.computeWorldMatrix(true); m.bakeCurrentTransformIntoVertices(); }
    const merged = parts.length === 1 ? parts[0] : Mesh.MergeMeshes(parts, true, true, undefined, false, true);
    if (!merged) return null;
    merged.setParent(null);
    merged.position.set(0, 0, 0); merged.rotationQuaternion = null; merged.rotation.set(0, 0, 0); merged.scaling.set(1, 1, 1);
    merged.computeWorldMatrix(true);
    const b = merged.getBoundingInfo().boundingBox;
    const footprint = Math.max(b.maximum.x - b.minimum.x, b.maximum.z - b.minimum.z) || 1;
    merged.isVisible = false; merged.isPickable = false;
    scene.addMesh(merged);
    for (const m of container.meshes) if (m !== merged && !(m as AbstractMesh).isDisposed()) m.dispose();
    return { mesh: merged, footprint, base: b.minimum.y, height: b.maximum.y - b.minimum.y };
  } catch {
    return null;
  }
}

export function QueenCombBabylon({ cards, workers, devices, onPick, pickIndex = null, fitInset = 0, events = EMPTY_EVENTS, modules, beeTargets }: QueenCombBabylonProps) {
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
  const modulesRef = useRef(modules);
  const targetsRef = useRef(beeTargets);
  useEffect(() => {
    cardsRef.current = cards;
    workersRef.current = workers;
    devicesRef.current = devices;
    modulesRef.current = modules;
    targetsRef.current = beeTargets;
  }, [cards, workers, devices, modules, beeTargets]);

  useEffect(() => {
    const canvas = canvasRef.current;
    const host = hostRef.current;
    if (!canvas || !host) return;
    const cards = cardsRef.current;
    const workers = workersRef.current;
    const devices = devicesRef.current;
    const cells = hexCellSummaries(cards);
    const home = HEX_HOME;
    const engine = new Engine(canvas, true, { preserveDrawingBuffer: false, stencil: false }, false);
    const scene = new Scene(engine);
    scene.clearColor = new Color4(2 / 255, 8 / 255, 6 / 255, 1);
    scene.skipPointerMovePicking = true;
    // the rendered look: tone mapping with a little contrast and a vignette,
    // depth fog into the void, and a glow on every emissive part (windows,
    // lamps, bands, rings) - what a game's post pass gives a low-poly scene
    const ipc = scene.imageProcessingConfiguration;
    ipc.toneMappingEnabled = true;
    ipc.contrast = 1.22;
    ipc.exposure = 1.08;
    ipc.vignetteEnabled = true;
    ipc.vignetteWeight = 1.6;
    ipc.vignetteColor = new Color4(0, 0.02, 0.01, 0);
    scene.fogMode = Scene.FOGMODE_LINEAR;
    scene.fogColor = new Color3(2 / 255, 8 / 255, 6 / 255);
    const glow = new GlowLayer("glow", scene, { blurKernelSize: 24 });
    glow.intensity = 0.55;

    // ---- extents and the RTS camera: fixed angle, zoom, no idle sway ------
    let minX = Infinity, maxX = -Infinity, minZ = Infinity, maxZ = -Infinity;
    for (const c of cells) {
      minX = Math.min(minX, c.x - S / 2); maxX = Math.max(maxX, c.x + S / 2);
      minZ = Math.min(minZ, c.y - HEX_R); maxZ = Math.max(maxZ, c.y + HEX_R);
    }
    const centre = new Vector3((minX + maxX) / 2, 0, (minZ + maxZ) / 2);
    const camera = new ArcRotateCamera("cam", Math.PI / 2 + 0.55, 0.95, 4000, centre.clone(), scene);
    const depth = Math.max(maxX - minX, maxZ - minZ);
    scene.fogStart = 4000 - depth * 0.1;
    scene.fogEnd = 4000 + depth * 1.4;
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
      const fieldW = (maxX - minX + S) * 1.02, fieldH = (maxZ - minZ + S) * Math.cos(camera.beta) * 1.02 + S * 1.3;
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
    drawTiles(tctx, 1024, 4);
    tex.update(false);
    const groundW = maxX - minX + MARGIN * 2, groundH = maxZ - minZ + MARGIN * 2;
    tex.uScale = groundW / (S * 4);
    tex.vScale = groundH / (S * 4);
    const groundMat = new StandardMaterial("ground", scene);
    groundMat.diffuseTexture = tex;
    groundMat.specularTexture = tex;
    groundMat.specularColor = new Color3(0.18, 0.19, 0.22);
    groundMat.specularPower = 48;
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
    // hazard stripes along the platform edge (the reference's yellow-black rails)
    const stripes = new DynamicTexture("stripes", { width: 256, height: 32 }, scene, false);
    const sctx = stripes.getContext() as CanvasRenderingContext2D;
    for (let i = 0; i < 16; i += 1) { sctx.fillStyle = i % 2 ? "#d9b230" : "#1a1a1a"; sctx.beginPath(); sctx.moveTo(i * 16, 0); sctx.lineTo(i * 16 + 16, 0); sctx.lineTo(i * 16 + 8, 32); sctx.lineTo(i * 16 - 8, 32); sctx.closePath(); sctx.fill(); }
    stripes.update(false);
    const stripeMat = new StandardMaterial("stripes", scene);
    stripeMat.diffuseTexture = stripes; stripeMat.emissiveColor = new Color3(0.35, 0.3, 0.1); stripeMat.specularColor = Color3.Black();
    for (const [w, d, x, z, rep] of [[groundW, 6, centre.x, centre.z - groundH / 2 + 3, groundW / 40], [groundW, 6, centre.x, centre.z + groundH / 2 - 3, groundW / 40], [6, groundH, centre.x - groundW / 2 + 3, centre.z, groundH / 40], [6, groundH, centre.x + groundW / 2 - 3, centre.z, groundH / 40]] as const) {
      const rail = CreateBox(`rail-${x}-${z}`, { width: w, depth: d, height: 3 }, scene);
      rail.position = new Vector3(x, 1.5, z);
      const m = stripeMat.clone(`stripes-${x}-${z}`);
      const t = stripes.clone(); t.uScale = w > d ? rep : 1; t.vScale = w > d ? 1 : rep; m.diffuseTexture = t;
      rail.material = m; rail.isPickable = false;
    }

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
    const u = S * 0.4;
    interface Template { parts: Mesh[]; matrices: number[]; scales: number[]; turns: number[]; heights: number[]; colors: number[] }
    const mods = modulesRef.current;
    const nowWall = Date.now();
    const templates: Record<Column, Template> = {} as Record<Column, Template>;
    const part = (m: Mesh, material: StandardMaterial, y: number, x = 0, z = 0) => { m.material = material; m.position.set(x, y, z); m.isPickable = false; m.isVisible = false; shadows.addShadowCaster(m); return m; };
    templates.backlog = { parts: [
      part(CreateBox("bl-slab", { width: u, depth: u, height: 5 }, scene), dark, 2.5),
      ...[[-1, -1], [1, -1], [-1, 1], [1, 1]].map(([px, pz], k) => part(CreateBox(`bl-post-${k}`, { width: 4, depth: 4, height: 16 }, scene), steel, 8, px * u * 0.42, pz * u * 0.42)),
    ], matrices: [], scales: [], turns: [], heights: [], colors: [] };
    templates.running = { parts: [
      part(CreateBox("ru-body", { width: u * 0.8, depth: u * 0.8, height: u * 0.55 }, scene), steel, u * 0.275),
      part(CreateBox("ru-band", { width: u * 0.84, depth: u * 0.84, height: 4 }, scene), cyan, u * 0.3),
      part(CreateCylinder("ru-mast", { diameter: 3, height: u * 0.6 }, scene), steel, u * 0.85, u * 0.25, u * 0.25),
      part(CreateSphere("ru-lamp", { diameter: 8 }, scene), cyan, u * 1.15, u * 0.25, u * 0.25),
    ], matrices: [], scales: [], turns: [], heights: [], colors: [] };
    templates.review = { parts: [
      part(CreateCylinder("rv-base", { diameter: u * 0.9, height: u * 0.3, tessellation: 12 }, scene), steel, u * 0.15),
      part(CreateSphere("rv-dome", { diameter: u * 0.7, slice: 0.5, segments: 12 }, scene), glass, u * 0.3),
      part(CreateTorus("rv-ring", { diameter: u * 0.72, thickness: 3, tessellation: 24 }, scene), gold, u * 0.31),
    ], matrices: [], scales: [], turns: [], heights: [], colors: [] };
    templates.done = { parts: [
      part(CreateBox("dn-tower", { width: u * 0.6, depth: u * 0.6, height: u * 1.1 }, scene), steel, u * 0.55),
      part(CreateBox("dn-win1", { width: u * 0.62, depth: u * 0.62, height: 3 }, scene), green, u * 0.35),
      part(CreateBox("dn-win2", { width: u * 0.62, depth: u * 0.62, height: 3 }, scene), green, u * 0.7),
      part(CreateBox("dn-cap", { width: u * 0.7, depth: u * 0.7, height: 6 }, scene), dark, u * 1.13),
    ], matrices: [], scales: [], turns: [], heights: [], colors: [] };
    // two more silhouettes for done cards, chosen by card number, so a hundred
    // finished tasks read as a base and not as a grid of one tower
    const doneDepot: Template = { parts: [
      part(CreateBox("dd-body", { width: u * 0.95, depth: u * 0.7, height: u * 0.35 }, scene), steel, u * 0.175),
      part(CreateBox("dd-roof", { width: u * 1.0, depth: u * 0.75, height: 4 }, scene), dark, u * 0.37),
      part(CreateBox("dd-strip", { width: u * 0.97, depth: u * 0.72, height: 2.5 }, scene), green, u * 0.2),
    ], matrices: [], scales: [], turns: [], heights: [], colors: [] };
    const doneSilo: Template = { parts: [
      part(CreateCylinder("ds-body", { diameter: u * 0.6, height: u * 0.8, tessellation: 14 }, scene), steel, u * 0.4),
      part(CreateSphere("ds-top", { diameter: u * 0.6, slice: 0.5, segments: 12 }, scene), dark, u * 0.8),
      part(CreateTorus("ds-band", { diameter: u * 0.62, thickness: 2.5, tessellation: 24 }, scene), green, u * 0.5),
    ], matrices: [], scales: [], turns: [], heights: [], colors: [] };
    templates.blocked = { parts: [
      part(CreateBox("bk-body", { width: u * 0.7, depth: u * 0.7, height: u * 0.4 }, scene), dark, u * 0.2),
      part(CreateTorus("bk-fence", { diameter: u * 0.95, thickness: 2.5, tessellation: 6 }, scene), red, 8),
      part(CreateBox("bk-light", { width: u * 0.72, depth: u * 0.72, height: 3 }, scene), red, u * 0.42),
    ], matrices: [], scales: [], turns: [], heights: [], colors: [] };
    templates.dropped = { parts: [
      part(CreateBox("dr-a", { width: u * 0.5, depth: u * 0.4, height: u * 0.18 }, scene), ruin, u * 0.09, -u * 0.12, u * 0.05),
      part(CreateBox("dr-b", { width: u * 0.3, depth: u * 0.3, height: u * 0.3 }, scene), ruin, u * 0.15, u * 0.2, -u * 0.15),
    ], matrices: [], scales: [], turns: [], heights: [], colors: [] };
    const bandTpl: Template = { parts: [part(CreateTorus("win-band", { diameter: u * 1.0, thickness: 2.2, tessellation: 4 }, scene), green, 0)], matrices: [], scales: [], turns: [], heights: [], colors: [] };
    cells.forEach((c, i) => {
      if (i === home) return;
      const card = cards[i];
      if (!card) return;
      const col = (COLUMNS as readonly string[]).includes(card.column) ? (card.column as Column) : "backlog";
      const m = mods?.get(card.number);
      const templateOf = (key: string) => (key === "doneDepot" ? doneDepot : key === "doneSilo" ? doneSilo : templates[(key in templates ? key : "backlog") as Column]);
      const tint: [number, number, number, number] = m ? buildingTint(m, nowWall) : [1, 1, 1, 1];
      const push = (t: Template, x: number, z: number, k: number, h: number, turn: number, y = 0) => {
        t.matrices.push(...Matrix.Compose(new Vector3(k, k * h, k), Quaternion.RotationAxis(Vector3.Up(), turn), new Vector3(x, y, z)).toArray());
        t.scales.push(k); t.turns.push(turn); t.heights.push(h); t.colors.push(...tint);
      };
      if (m) {
        // the shape grammar: the building is the plan's parts, in the core's frame
        const plan = buildingPlan(m);
        const cos = Math.cos(plan.turn), sin = Math.sin(plan.turn);
        for (const part of plan.parts) {
          if (part.model === "band") {
            // a lit ring at its level up the core: the core's model height is
            // unknown until loaded, so the level is in cell units
            push(bandTpl, c.x, c.y, part.scale, 1, plan.turn + Math.PI / 4, u * 0.28 * (part.level ?? 1) * part.height);
            continue;
          }
          const key = part.model === "core" ? plan.core : PART_MODEL[part.model];
          const x = c.x + (part.dx * cos - part.dz * sin) * u * 2, z = c.y + (part.dx * sin + part.dz * cos) * u * 2;
          push(templateOf(key), x, z, part.scale, part.height, plan.turn);
        }
        // an open issue on a module fences it in red (the blocked template's fence)
        if (m.openIssues.length > 0 && plan.core !== "blocked") push(templates.blocked, c.x, c.y, plan.parts[0].scale, 1, 0);
      } else {
        const key = col === "done" ? (["done", "doneDepot", "doneSilo"] as const)[card.number % 3] : col;
        push(templateOf(key), c.x, c.y, 1, 1, 0);
      }
    });
    for (const t of [...COLUMNS.map((col) => templates[col]), doneDepot, doneSilo, bandTpl]) {
      const count = t.matrices.length / 16;
      for (const p of t.parts) {
        if (count === 0) { p.dispose(); continue; }
        p.isVisible = true;
        p.thinInstanceSetBuffer("matrix", new Float32Array(t.matrices), 16, true);
        if (t.colors.length === count * 4) p.thinInstanceSetBuffer("color", new Float32Array(t.colors), 4, true);
      }
    }
    const hub = part(CreateCylinder("hub", { diameter: S * 0.9, height: 10, tessellation: 24 }, scene), steel, 5, cells[home].x, cells[home].y);
    hub.isVisible = true;
    const hubDome = part(CreateSphere("hub-dome", { diameter: S * 0.5, slice: 0.5, segments: 16 }, scene), gold, 10, cells[home].x, cells[home].y);
    hubDome.isVisible = true;


    // ---- rings: picked (gold), hover (dashed, territory colour) ---------
    const ring7 = () => [Array.from({ length: 7 }, () => new Vector3(0, 0, 0))];
    const picked = CreateLineSystem("picked", { lines: ring7(), updatable: true }, scene);
    picked.color = Color3.FromHexString("#FFD45A"); picked.isPickable = false;
    // a cell's outline is its hexagon, inset a little so the ring reads as the cell's, not the neighbour's
    const hexOf = (i: number): [number, number][] => hexCornersAt(cells[i].x, cells[i].y, HEX_R, 4).map((c) => [c.x, c.y]);
    const placeRing = (mesh: LinesMesh, i: number, y: number) => {
      const p = hexOf(i); const pts = [...p, p[0]];
      const buf = mesh.getVerticesData(VertexBuffer.PositionKind);
      if (!buf) return;
      pts.forEach(([px, pz], k) => { buf[k * 3] = px; buf[k * 3 + 1] = y; buf[k * 3 + 2] = pz; });
      mesh.updateVerticesData(VertexBuffer.PositionKind, buf);
      mesh.isVisible = true;
    };
    const hovered = CreateDashedLines("hover", { points: Array.from({ length: 7 }, (_, k) => new Vector3(Math.cos(k), 0, Math.sin(k))), dashSize: 3, gapSize: 2, dashNb: 60, updatable: true }, scene);
    hovered.alpha = 0.8; hovered.isPickable = false; hovered.isVisible = false;
    const placeDashed = (i: number, y: number) => {
      const p = hexOf(i);
      CreateDashedLines("hover", { points: [...p, p[0]].map(([px, pz]) => new Vector3(px, y, pz)), dashSize: 3, gapSize: 2, dashNb: 60, instance: hovered }, scene);
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
    const crystalSprites: Sprite[] = [];
    (devices ?? []).forEach((d, k) => { const r = ring[k]; if (r) { const sp = put(`crystal-${crystalOf(d.family)}`, r.i, S * 0.4, 0, 64); if (sp) crystalSprites.push(sp); } });

    const running = cells.map((c, i) => ({ c, i })).filter(({ i }) => cards[i]?.column === "running").map(({ i }) => i);
    const indexByNumber = new Map<number, number>();
    cells.forEach((c, i) => { if (c.cardNumber !== null) indexByNumber.set(c.cardNumber, i); });
    interface Bee { slot: number; busy: boolean; work: boolean; from: number; to: number; t: number; speed: number; hover: number; line: BeeLine; body: Sprite; larva: Sprite; bodyModel?: InstancedMesh; bodyK?: number; bodyBase?: number; larvaModel?: InstancedMesh; larvaK?: number; larvaBase?: number }
    const bees: Bee[] = (workers?.slots ?? []).map((slot, k) => {
      const line = LINES[k % LINES.length];
      const body = new Sprite(`bee-${slot.slot}`, manager(line, 16));
      const larva = new Sprite(`larva-${slot.slot}`, manager("larva", 16));
      const size = line === "scribe" ? S * 0.28 : line === "wright" ? S * 0.34 : S * 0.4;
      body.width = size; body.height = size; body.isVisible = false;
      larva.width = S * 0.3; larva.height = larva.width; larva.isVisible = false;
      return { slot: slot.slot, busy: false, work: false, from: home, to: home, t: 1, speed: 0, hover: k * 1.7, line, body, larva };
    });
    const ringCell = (rank: number) => { const r = ring[(devices?.length ?? 0) + rank]; return r ? r.i : home; };
    const aimBees = () => {
      const slots = new Map<number, "busy" | "idle">();
      for (const slot of workersRef.current?.slots ?? []) slots.set(slot.slot, slot.state);
      let busyRank = 0, idleRank = 0;
      const issueTargets = targetsRef.current;
      for (const b of bees) {
        b.busy = slots.get(b.slot) === "busy";
        let target = home;
        if (b.busy) { const byIssue = issueTargets ? issueTargets[busyRank] : undefined; target = byIssue ?? running[busyRank] ?? home; b.work = (byIssue !== undefined && byIssue !== null) || running[busyRank] !== undefined; busyRank += 1; }
        else { b.work = false; target = ringCell(idleRank); idleRank += 1; }
        if (b.to !== target) { b.from = b.t < 0.5 ? b.from : b.to; b.to = target; b.t = 0; b.speed = b.busy ? 0.55 : 0.35; }
      }
    };
    aimBees();
    const beeAt = (index: number) => bees.find((b) => (b.t < 0.5 ? b.from : b.to) === index) ?? null;
    const flightLines = bees.map((b) => { const m = CreateDashedLines(`flight-${b.slot}`, { points: [new Vector3(0, 0, 0), new Vector3(1, 0, 1)], dashSize: 6, gapSize: 4, dashNb: 40, updatable: true }, scene); m.color = Color3.FromHexString("#64DCFF"); m.alpha = 0.55; m.isPickable = false; m.isVisible = false; return m; });
    const unitRings = bees.map((b) => { const m = CreateTorus(`unit-ring-${b.slot}`, { diameter: b.body.width * 0.8, thickness: 1.6, tessellation: 20 }, scene); m.material = green; m.isPickable = false; m.isVisible = false; return m; });

    // The glTF loader creates PBR materials, and a PBR material's first use
    // schedules the environment BRDF lookup texture, generated asynchronously
    // through executeWhenCompiled; when the view switches mid-load that
    // callback ran on a disposed engine (TypeError: reading 'program'). The
    // models become StandardMaterials anyway, so the scene gets a 2x2 stand-in
    // BRDF texture up front and nothing is ever generated.
    if (!scene.environmentBRDFTexture) scene.environmentBRDFTexture = new DynamicTexture("brdf-none", 2, scene, false);
    // ---- the Kenney models replace the procedural templates as they load;
    //      a model that fails to load leaves its procedural stand-in --------
    let disposed = false;
    const modelInstances = new Map<ModelKey, { mesh: Mesh; footprint: number; base: number; height: number }>();
    const placeModel = (t: { mesh: Mesh; footprint: number; base: number }, matrices: number[], target: number, parts: Mesh[], scales: number[] = [], turns: number[] = [], heights: number[] = [], colors: number[] = []) => {
      if (disposed || scene.isDisposed || matrices.length === 0) return;
      const out: number[] = [];
      for (let i = 0, j = 0; i < matrices.length; i += 16, j += 1) {
        const tx = matrices[i + 12], tz = matrices[i + 14];
        const k = (target / t.footprint) * (scales[j] ?? 1), h = heights[j] ?? 1;
        out.push(...Matrix.Compose(new Vector3(k, k * h, k), Quaternion.RotationAxis(Vector3.Up(), turns[j] ?? 0), new Vector3(tx, -t.base * k * h, tz)).toArray());
      }
      t.mesh.thinInstanceSetBuffer("matrix", new Float32Array(out), 16, true);
      // the per-instance tint (M-4): StandardMaterial multiplies its palette by it
      if (colors.length === (matrices.length / 16) * 4) t.mesh.thinInstanceSetBuffer("color", new Float32Array(colors), 4, true);
      t.mesh.isVisible = true;
      shadows.addShadowCaster(t.mesh);
      for (const p of parts) p.dispose();
    };
    const unitInstances: Array<{ key: ModelKey; node: InstancedMesh; k: number; base: number }> = [];
    void (async () => {
      const keys: ModelKey[] = ["backlog", "running", "review", "done", "doneDepot", "doneSilo", "blocked", "dropped", "hub", "crystal", "scribe", "wright", "lapidary", "larva"];
      const loaded = await Promise.all(keys.map(async (key) => [key, await loadTemplate(scene, key)] as const));
      if (disposed || scene.isDisposed) { for (const [, t] of loaded) t?.mesh.dispose(); return; }
      for (const [key, t] of loaded) if (t) modelInstances.set(key, t);
      const bind = (key: ModelKey, tpl: Template, target: number) => { const t = modelInstances.get(key); if (t) placeModel(t, tpl.matrices, target, tpl.parts, tpl.scales, tpl.turns, tpl.heights, tpl.colors); };
      // a building takes about half a cell, so the roads between them still show
      bind("backlog", templates.backlog, u * 1.3); bind("running", templates.running, u * 1.25); bind("review", templates.review, u * 1.3);
      bind("done", templates.done, u * 1.35); bind("doneDepot", doneDepot, u * 1.35); bind("doneSilo", doneSilo, u * 1.25);
      bind("blocked", templates.blocked, u * 1.3); bind("dropped", templates.dropped, u * 1.2);
      const hubT = modelInstances.get("hub");
      if (hubT) { placeModel(hubT, [...Matrix.Translation(cells[home].x, 0, cells[home].y).toArray()], S * 1.25, [hub, hubDome]); }
      const crystalT = modelInstances.get("crystal");
      if (crystalT) {
        const mats: number[] = [];
        (devices ?? []).forEach((_, k2) => { const r = ring[k2]; if (r) mats.push(...Matrix.Translation(cells[r.i].x, 0, cells[r.i].y).toArray()); });
        placeModel(crystalT, mats, u * 1.0, []);
        for (const sp of crystalSprites) sp.dispose();
      }
      // units: one instance per bee (walking model) and one per larva (the alien)
      bees.forEach((b) => {
        const walk = modelInstances.get(b.line); const idle = modelInstances.get("larva");
        if (walk) { const k = (S * 0.3) / walk.footprint; const inst = walk.mesh.createInstance(`unit-${b.slot}`); inst.scaling.set(k, k, k); inst.isPickable = false; inst.isVisible = false; unitInstances.push({ key: b.line, node: inst, k, base: walk.base }); b.bodyModel = inst; b.bodyK = k; b.bodyBase = walk.base; b.body.isVisible = false; b.body.dispose(); }
        if (idle) { const k = (S * 0.26) / idle.footprint; const inst = idle.mesh.createInstance(`larva-${b.slot}`); inst.scaling.set(k, k, k); inst.isPickable = false; inst.isVisible = false; b.larvaModel = inst; b.larvaK = k; b.larvaBase = idle.base; b.larva.dispose(); }
      });
    })();

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
        // a verdict re-stamped by the tick is the same verdict: no new glint (P0-10)
        const identity = eventIdentity(event);
        if (seen.has(identity)) continue;
        seen.add(identity);
        if (!primed && wall - new Date(event.at).getTime() > 30_000) continue;
        const index = event.issue !== null ? indexByNumber.get(event.issue) : undefined;
        if (index === undefined) continue;
        effects.push({ index, tone: eventTone(event.kind), start: stamp, flip: false });
      }
      eventsPrimedRef.current = true;
      if (seen.size > 2000) seenEventsRef.current = new Set(list.map(eventIdentity));
    };

    // ---- picking and hover ---------------------------------------------------
    const cellUnder = (x: number, y: number) => {
      const hit = scene.pick(x, y, (m) => m === ground);
      if (!hit?.hit || !hit.pickedPoint) return -1;
      return hexIndexAt(hit.pickedPoint.x, hit.pickedPoint.z, cells.length);
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
      if (index < 0) { host.setAttribute("data-hit", "off"); return; }
      const card = cards[index];
      // a cell with no module is empty ground (P1-10): the click clears the
      // selection, as on an RTS map, and never picks a cardless cell
      if (!card && index !== home) { host.setAttribute("data-hit", "void"); onPickRef.current?.(null); return; }
      host.setAttribute("data-hit", index === home ? "queen" : "module");
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
      // The box can change while no frame runs (a hidden pane, fullscreen,
      // a pane resized before it is shown); a ResizeObserver alone missed
      // that and left the field clipped to the old canvas. Check every frame.
      const cw = canvas.clientWidth, ch = canvas.clientHeight;
      if ((cw > 0 && ch > 0) && (canvas.width !== cw || canvas.height !== ch)) { engine.resize(); fit(); }
      if (insetRef.current !== appliedInset) fit();
      aimBees();
      bees.forEach((b, k) => {
        if (b.t < 1) b.t = Math.min(1, b.t + (b.speed * dt) / 1000);
        const A = cells[b.from], B = cells[b.to];
        if (!A || !B) return;
        const e = b.t < 0.5 ? 2 * b.t * b.t : 1 - 2 * (1 - b.t) * (1 - b.t);
        let x = A.x + (B.x - A.x) * e, z = A.y + (B.y - A.y) * e;
        if (b.t >= 1 && b.busy) { const ph = nowMs / 700 + b.hover; x = B.x + Math.cos(ph) * S * 0.12; z = B.y + Math.sin(ph * 1.3) * S * 0.08; }
        const model = b.busy ? b.bodyModel : b.larvaModel;
        const other = b.busy ? b.larvaModel : b.bodyModel;
        if (other) other.isVisible = false;
        if (model) {
          const mk = (b.busy ? b.bodyK : b.larvaK) ?? 1, mb = (b.busy ? b.bodyBase : b.larvaBase) ?? 0;
          model.isVisible = true;
          model.position.set(x, -mb * mk + (b.busy ? Math.abs(Math.sin(nowMs / 140 + k)) * 2 : 0), z);
          if (b.t < 1) model.rotation.y = Math.atan2(B.x - A.x, B.y - A.y);
          b.body.isVisible = false; b.larva.isVisible = false;
        } else {
          const sprite = b.busy ? b.body : b.larva;
          b.body.isVisible = b.busy; b.larva.isVisible = !b.busy;
          sprite.position.x = x; sprite.position.z = z;
          sprite.position.y = sprite.height / 2 + (b.busy ? 2 + Math.abs(Math.sin(nowMs / 140 + k)) * 3 : 1);
          sprite.invertU = B.x - A.x < 0;
        }
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
      // no hover ring on empty ground (P1-10): only modules and the Queen's hub answer the pointer
      if (hover >= 0 && hover !== p && cells[hover] && (cards[hover] || hover === home)) placeDashed(hover, 1.4); else hovered.isVisible = false;
      scene.render();
      frames += 1;
      if (frames === 1) host.setAttribute("data-first-frame-ms", String(Math.round(nowMs - t0)));
      host.setAttribute("data-frames", String(frames));
    });
    const ro = new ResizeObserver(() => { engine.resize(); fit(); });
    ro.observe(host);
    const onVisible = () => { engine.resize(); fit(); };
    document.addEventListener("visibilitychange", onVisible);
    document.addEventListener("fullscreenchange", onVisible);
    return () => {
      disposed = true;
      document.removeEventListener("visibilitychange", onVisible);
      document.removeEventListener("fullscreenchange", onVisible);
      ro.disconnect(); engine.stopRenderLoop(); scene.dispose(); engine.dispose();
    };
  }, [signature]);

  return (
    <div className="queen27-comb is-embedded is-babylon">
      <div className="queen27-comb-field" ref={hostRef} data-engine="babylon" data-look="platform" data-grid="hex">
        <canvas ref={canvasRef} style={{ touchAction: "none", outline: "none" }} />
      </div>
    </div>
  );
}
