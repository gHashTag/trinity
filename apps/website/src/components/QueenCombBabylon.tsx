// The comb in Babylon.js as a GAME FIELD (the user, 2026-09-04 11:10Z, with a
// StarCraft screenshot: "I want a field like THIS"): one continuous plate of
// steel tiles with the mark engraved in every tile, low-poly buildings with
// volume standing where the cards stand, bees as units on the ground, an RTS
// camera (fixed angle, zoom, no idle sway). The cells still come from
// summariseCells, so placement, picking, the pairing of bees to running cards
// and the event glints keep their rules; only the picture changed. Buildings
// are procedural until the user names an asset pack (B-5).
import { ImageProcessingConfiguration } from "@babylonjs/core/Materials/imageProcessingConfiguration";
import { useEffect, useRef , useImperativeHandle } from "react";
import type { Ref } from "react";
import { TransformNode } from "@babylonjs/core/Meshes/transformNode";
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
import { CreateCylinder } from "@babylonjs/core/Meshes/Builders/cylinderBuilder";
import { HemisphericLight } from "@babylonjs/core/Lights/hemisphericLight";
import { DirectionalLight } from "@babylonjs/core/Lights/directionalLight";
import "@babylonjs/core/Lights/Shadows/shadowGeneratorSceneComponent";
import { GlowLayer } from "@babylonjs/core/Layers/glowLayer";
import "@babylonjs/core/Layers/effectLayerSceneComponent";
import "@babylonjs/core/Meshes/thinInstanceMesh";
import { LoadAssetContainerAsync } from "@babylonjs/core/Loading/sceneLoader";
import "@babylonjs/loaders/glTF";
import type { AbstractMesh } from "@babylonjs/core/Meshes/abstractMesh";
import type { PBRMaterial } from "@babylonjs/core/Materials/PBR/pbrMaterial";
import type { BaseTexture } from "@babylonjs/core/Materials/Textures/baseTexture";
import type { LinesMesh } from "@babylonjs/core/Meshes/linesMesh";
import { PointerEventTypes } from "@babylonjs/core/Events/pointerEvents";
import { Ray } from "@babylonjs/core/Culling/ray";
import { S } from "./QueenComb";
import { buildingPlan, eventTone, ringTone, type BeeLine, type HudEvent, type HudModule, type HudPick, type Tone , eventIdentity , hexCellSummaries, hexIndexAt, hexCornersAt, HEX_HOME, HEX_R, foundationCells, honeyTone, spiralAxial, S_CELL, type FoundationIssue,
 FIELD_LAYERS, type FieldLayer, type CombHandle,
 castlePlaces, ringOfEpic, towerStage, ringSummary, ringFamily, familyTint, ringOfModulePath, epicOfIssue, hexRingStart, CASTLE_RING, type TowerStage, type EpicRecord,
} from "./queenHud";

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
  /** The honeycomb foundation: the loop's snapshot of closed GitHub issues, one honey hex each. */
  foundation?: { issues: FoundationIssue[]; generatedAt: string; source: "wire" | "file"; rings?: string[]; epics?: EpicRecord[]; releases?: Array<{ tag: string; name: string; publishedAt: string | null; prerelease: boolean }> } | null;
  /** Which layers draw: FOUNDATION (tiles and honey), CASTLE (the rings' towers), CODE (the module buildings). Bees always. */
  layers?: Record<FieldLayer, boolean>;
  /** The toolbar's zoom and fit, the same handle the canvas comb exposes. */
  handleRef?: Ref<CombHandle>;
}
// the plan's part kinds map to models the field loads: annexes are the
// platform, antennae the dish; the core is the plan's own key

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
  // ONE KIT (Kenney Hexagon Kit, CC0). The kingdom is built from one set of
  // parts, so a silhouette on the field always means the same thing.
  // the CODE layer: the settlement a module becomes, by the column it sits in
  backlog: "hex-building-cabin", running: "hex-building-mill", review: "hex-building-archery",
  done: "hex-building-house", doneDepot: "hex-building-market", doneSilo: "hex-building-farm",
  blocked: "hex-building-wall", dropped: "hex-stone-rocks",
  // the CASTLE layer: a plinth per ring, a tower by the stage of its epics
  plinth: "hex-stone", walls: "hex-building-walls", tower: "hex-building-tower",
  wizardTower: "hex-building-wizard-tower", unitTower: "hex-unit-tower",
  // the throne at the hub, always visible: the Queen's own castle
  keep: "hex-building-castle",
} as const;
type ModelKey = keyof typeof MODELS;

/** Point-in-down-triangle for the cell under a world point (x, z). */


/**
 * Load a Kenney GLB and merge it into one mesh with a multi-material, so it
 * can be thin-instanced like the procedural templates. Returns the mesh and
 * its footprint (the flat width: min of width and depth) and base (min y), both in model
 * units, so the caller can scale it to a cell and stand it on the ground.
 */
async function loadTemplate(scene: Scene, key: ModelKey): Promise<{ mesh: Mesh; footprint: number; base: number; height: number; width: number; depth: number } | null> {
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
    // a hex tile measures 1.000 flat-to-flat and 1.1547 corner-to-corner, so the
    // FLAT width is the fit: dividing by the larger left a moat around every building
    const footprint = Math.min(b.maximum.x - b.minimum.x, b.maximum.z - b.minimum.z) || 1;
    merged.isVisible = false; merged.isPickable = false;
    scene.addMesh(merged);
    for (const m of container.meshes) if (m !== merged && !(m as AbstractMesh).isDisposed()) m.dispose();
    return { mesh: merged, footprint, base: b.minimum.y, height: b.maximum.y - b.minimum.y, width: b.maximum.x - b.minimum.x, depth: b.maximum.z - b.minimum.z };
  } catch {
    return null;
  }
}

const ALL_LAYERS: Record<FieldLayer, boolean> = { foundation: true, castle: true, code: true };

export function QueenCombBabylon({ cards, workers, onPick, pickIndex = null, fitInset = 0, events = EMPTY_EVENTS, modules, beeTargets, foundation = null, layers = ALL_LAYERS, handleRef }: QueenCombBabylonProps) {
  const hostRef = useRef<HTMLDivElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const cardRef = useRef<HTMLDivElement>(null);
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
    // a new snapshot of the foundation rebuilds the honey like a modules change rebuilds the city
    foundation ? [foundation.generatedAt, foundation.issues.length] : null,
  ]);
  const cardsRef = useRef(cards);
  const workersRef = useRef(workers);
  const modulesRef = useRef(modules);
  const targetsRef = useRef(beeTargets);
  const foundationRef = useRef(foundation);
  const layersRef = useRef(layers);
  const cameraRef = useRef<CombHandle | null>(null);
  useEffect(() => {
    cardsRef.current = cards;
    workersRef.current = workers;
    modulesRef.current = modules;
    targetsRef.current = beeTargets;
    foundationRef.current = foundation;
    layersRef.current = layers;
  }, [cards, workers, modules, beeTargets, foundation, layers]);

  useImperativeHandle(handleRef, () => ({
    zoomIn: () => cameraRef.current?.zoomIn(),
    zoomOut: () => cameraRef.current?.zoomOut(),
    fit: () => cameraRef.current?.fit(),
  }), []);
  useEffect(() => {
    const canvas = canvasRef.current;
    const host = hostRef.current;
    if (!canvas || !host) return;
    const cards = cardsRef.current;
    const workers = workersRef.current;
    const cells = hexCellSummaries(cards);
    const home = HEX_HOME;
    // the honey under the cells (H-C2): the same map the click reads (H-E)
    const fdNow = foundationRef.current;
    const fCells = fdNow ? foundationCells(fdNow.issues, cells.length) : null;
    // the castle's testimony starts honest: no snapshot, no castle facts
    host.setAttribute("data-castle-source", fdNow ? fdNow.source : "none");
    if (!fdNow) { host.removeAttribute("data-castle-stages"); host.removeAttribute("data-castle-rings"); host.removeAttribute("data-castle-unassigned"); host.removeAttribute("data-castle-releases"); }
    const engine = new Engine(canvas, true, { preserveDrawingBuffer: false, stencil: false }, false);
    const scene = new Scene(engine);
    scene.clearColor = new Color4(2 / 255, 8 / 255, 6 / 255, 1);
    scene.skipPointerMovePicking = true;
    // the rendered look: tone mapping with a little contrast and a vignette,
    // depth fog into the void, and a glow on every emissive part (windows,
    // lamps, bands, rings) - what a game's post pass gives a low-poly scene
    const ipc = scene.imageProcessingConfiguration;
    ipc.toneMappingEnabled = true;
    ipc.toneMappingType = ImageProcessingConfiguration.TONEMAPPING_ACES;
    ipc.contrast = 1.22;
    ipc.exposure = 1.08;
    ipc.vignetteEnabled = true;
    ipc.vignetteWeight = 1.6;
    ipc.vignetteColor = new Color4(0, 0.02, 0.01, 0);
    // as a post-process the grade lands on the lines too (V-9): without this the
    // 1009 comb outlines, the pick ring and the flight lines render raw over a
    // graded world, which is the mechanical form of "the visual does not agree"
    ipc.applyByPostProcess = true;
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
    // the ground is a plane, not a mesh: a screen point becomes a world point by
    // solving the picking ray against y = PICK_Y, the height the comb is drawn on
    const PICK_Y = 1.5;
    const pickRay = new Ray(Vector3.Zero(), Vector3.Up(), Number.MAX_VALUE);
    const groundAt = (x: number, y: number): { x: number; z: number } | null => {
      scene.createPickingRayToRef(x, y, null, pickRay, camera);
      const dy = pickRay.direction.y;
      if (Math.abs(dy) < 1e-6) return null;
      const t = (PICK_Y - pickRay.origin.y) / dy;
      if (t < 0) return null;
      return { x: pickRay.origin.x + pickRay.direction.x * t, z: pickRay.origin.z + pickRay.direction.z * t };
    };
    const depth = Math.max(maxX - minX, maxZ - minZ);
    scene.fogStart = 4000 - depth * 0.1;
    scene.fogEnd = 4000 + depth * 1.4;
    camera.mode = Camera.ORTHOGRAPHIC_CAMERA;
    camera.lowerBetaLimit = 0.95; camera.upperBetaLimit = 0.95;
    camera.lowerAlphaLimit = camera.alpha; camera.upperAlphaLimit = camera.alpha;
    camera.panningSensibility = 0;
    let zoom = 1;
    let zoomGoal = 1;
    let anchor: { x: number; z: number } | null = null;
    let appliedInset = -1;
    // the castle's couplings to the code and the honey (K-5): filled when the snapshot lands
    let castleLinks: { plinthOfRing: Map<string, number>; ringOfCell: Map<number, string>; cellsOfRing: Map<string, number[]>; epics: EpicRecord[]; rings: string[] } | null = null;
    let linkLines: LinesMesh | null = null; let linkFor: string | null = null;
    let rootLines: LinesMesh | null = null;
    // three transform nodes carry the layers: a disabled parent hides its thin-instanced children without touching a buffer
    const layerNodes: Record<FieldLayer, TransformNode> = { foundation: new TransformNode("layer-foundation", scene), castle: new TransformNode("layer-castle", scene), code: new TransformNode("layer-code", scene) };
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
      host.setAttribute("data-zoom", zoom.toFixed(2));
    };
    fit();
    // the map answers the hand (the user, 2026-09-06). The camera had no inputs
    // at all: attachControl was never called, so panningSensibility configured
    // a manager that does not exist and a drag moved nothing. Both the drag and
    // the wheel now work against the same y = 0 plane the pick uses, so the
    // point under the cursor is the point that follows it.
    const ROAM = Math.max(maxX - minX, maxZ - minZ) * 0.55;
    const clampTarget = () => {
      camera.target.x = Math.min(Math.max(camera.target.x, centre.x - ROAM), centre.x + ROAM);
      camera.target.z = Math.min(Math.max(camera.target.z, centre.z - ROAM), centre.z + ROAM);
    };
    const onWheel = (e: WheelEvent) => {
      e.preventDefault();
      const r = canvas.getBoundingClientRect();
      anchor = groundAt(e.clientX - r.left, e.clientY - r.top);
      zoomGoal = Math.min(8, Math.max(0.5, zoomGoal * Math.exp(-e.deltaY * 0.0016)));
      host.setAttribute("data-zoom-goal", zoomGoal.toFixed(2));
    };
    canvas.addEventListener("wheel", onWheel, { passive: false });
    let grab: { x: number; y: number } | null = null;
    const onDown = (e: PointerEvent) => { if (e.button !== 0) return; grab = { x: e.clientX, y: e.clientY }; canvas.setPointerCapture(e.pointerId); };
    const onMove = (e: PointerEvent) => {
      if (!grab) return;
      const r = canvas.getBoundingClientRect();
      const a = groundAt(grab.x - r.left, grab.y - r.top), b = groundAt(e.clientX - r.left, e.clientY - r.top);
      if (a && b) { camera.target.x += a.x - b.x; camera.target.z += a.z - b.z; clampTarget(); fit(); }
      grab = { x: e.clientX, y: e.clientY };
    };
    const onUp = (e: PointerEvent) => { grab = null; if (canvas.hasPointerCapture(e.pointerId)) canvas.releasePointerCapture(e.pointerId); };
    canvas.addEventListener("pointerdown", onDown);
    canvas.addEventListener("pointermove", onMove);
    canvas.addEventListener("pointerup", onUp);
    canvas.addEventListener("pointercancel", onUp);
    // the toolbar's FIT VIEW / - / + reach the scene through the same handle the canvas comb exposes
    cameraRef.current = {
      zoomIn: () => { anchor = null; zoom = zoomGoal = Math.min(8, zoom * 1.25); fit(); },
      zoomOut: () => { anchor = null; zoom = zoomGoal = Math.max(0.5, zoom / 1.25); fit(); },
      // FIT VIEW is the way home: it undoes the roam as well as the zoom
      fit: () => { anchor = null; zoom = zoomGoal = 1; camera.target.copyFrom(centre); fit(); },
    };

    // ---- light: a sun from the upper left and a soft sky, shadows on -----
    const sky = new HemisphericLight("sky", new Vector3(0.2, 1, 0.1), scene);
    sky.intensity = 0.55;
    sky.groundColor = new Color3(0.12, 0.14, 0.18);
    const sun = new DirectionalLight("sun", new Vector3(-0.6, -1, 0.35), scene);
    sun.intensity = 1.1;
    sun.position = new Vector3(centre.x + 800, 1400, centre.z - 500);
    // no shadow generator: the plate that received the shadows is gone, so a
    // 2048 map was rendered every frame for nothing (V-11)

    // ---- no plate: the ground is a number, not a mesh ---------------------
    // The plate was a rectangle two cells wider than a hexagonal comb, so about
    // a thousand units of bare slab stuck out at every corner and caught the
    // sun where there is no field. It carried no fact and it was the only
    // straight edge on the board. y = 0 is a plane; a plane has no vertices,
    // no material and no draw call, and the pick solves against it in maths.
    // ---- buildings: one Hexagon Kit model per cell, thin-instanced ---------
    // No stand-ins (V-10). Until a GLB resolves the cell stays empty, and a
    // model that fails to load reports itself on the host, instead of leaving
    // 26 boxes and cylinders behind in a second, sci-fi art language.
    interface Template { matrices: number[]; scales: number[]; turns: number[]; heights: number[]; colors: number[] }
    const emptyTemplate = (): Template => ({ matrices: [], scales: [], turns: [], heights: [], colors: [] });
    const mods = modulesRef.current;
    const nowWall = Date.now();
    const templates: Record<Column, Template> = Object.fromEntries(COLUMNS.map((c) => [c, emptyTemplate()])) as Record<Column, Template>;
    const doneDepot = emptyTemplate(), doneSilo = emptyTemplate();
    cells.forEach((c, i) => {
      if (i === home) return;
      const card = cards[i];
      if (!card) return;
      const col = (COLUMNS as readonly string[]).includes(card.column) ? (card.column as Column) : "backlog";
      const m = mods?.get(card.number);
      const templateOf = (key: string) => (key === "doneDepot" ? doneDepot : key === "doneSilo" ? doneSilo : templates[(key in templates ? key : "backlog") as Column]);
      // no tint on the settlements: the kit's own palette reads, and colour on
      // this field means one thing only - gold is done (the comb carries it)
      const tint: [number, number, number, number] = [1, 1, 1, 1];
      const push = (t: Template, x: number, z: number, k: number, h: number, turn: number, y = 0) => {
        t.matrices.push(...Matrix.Compose(new Vector3(k, k * h, k), Quaternion.RotationAxis(Vector3.Up(), turn), new Vector3(x, y, z)).toArray());
        t.scales.push(k); t.turns.push(turn); t.heights.push(h); t.colors.push(...tint);
      };
      if (m) {
        // ONE model per cell. Every Hexagon Kit building carries its own hex
        // base, so the old multi-part plan stacked hex on hex and the middle of
        // the field turned to mush. The plan still chooses the core and the
        // turn; a module with an open issue shows the wall instead of its trade.
        const plan = buildingPlan(m);
        const key = m.openIssues.length > 0 && plan.core !== "blocked" ? "blocked" : plan.core;
        push(templateOf(key), c.x, c.y, 1, 1, plan.turn);
      } else {
        const key = col === "done" ? (["done", "doneDepot", "doneSilo"] as const)[card.number % 3] : col;
        push(templateOf(key), c.x, c.y, 1, 1, 0);
      }
    });

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
    // the hover card (the user, 2026-09-06): the hovered cell's issue, named beside the pointer
    let hoverIssue = -1;
    let pointerXY: [number, number] = [0, 0];
    const showHoverCard = (i: number) => {
      const card = cardRef.current;
      if (!card) return;
      const issue = i >= 0 ? fCells?.[i] ?? null : null;
      if (!issue) {
        if (hoverIssue !== -1) { hoverIssue = -1; card.setAttribute("aria-hidden", "true"); card.replaceChildren(); host.removeAttribute("data-hover-issue"); }
        return;
      }
      if (issue.number !== hoverIssue) {
        hoverIssue = issue.number;
        const head = document.createElement("b"); head.textContent = `#${issue.number} ${issue.title}`;
        const meta = document.createElement("span");
        meta.textContent = [issue.closedAt.slice(0, 16).replace("T", " "), ...issue.labels].join(" \u00b7 ");
        card.replaceChildren(head, meta);
        card.setAttribute("aria-hidden", "false");
        host.setAttribute("data-hover-issue", String(issue.number));
      }
      const r = host.getBoundingClientRect();
      card.style.left = `${Math.round(Math.min(Math.max(pointerXY[0] + 16, 8), Math.max(8, r.width - 316)))}px`;
      card.style.top = `${Math.round(Math.min(Math.max(pointerXY[1] + 16, 8), Math.max(8, r.height - 72)))}px`;
    };
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

    const running = cells.map((c, i) => ({ c, i })).filter(({ i }) => cards[i]?.column === "running").map(({ i }) => i);
    const indexByNumber = new Map<number, number>();
    cells.forEach((c, i) => { if (c.cardNumber !== null) indexByNumber.set(c.cardNumber, i); });
    // The swarm is anonymous by the server's decision, so every bee is the same
    // mote: one glowing hex, bright while it works. Three sprite costumes used
    // to imply a distinction the wire does not carry; cut 2026-09-06.
    const moteMat = new StandardMaterial("mote", scene);
    moteMat.diffuseColor = new Color3(0.5, 0.4, 0.14); moteMat.emissiveColor = new Color3(0.95, 0.74, 0.28); moteMat.specularColor = Color3.Black();
    interface Bee { slot: number; busy: boolean; work: boolean; from: number; to: number; t: number; speed: number; hover: number; line: BeeLine; mote: Mesh }
    const bees: Bee[] = (workers?.slots ?? []).map((slot, k) => {
      const mote = CreateCylinder(`bee-${slot.slot}`, { tessellation: 6, diameter: S * 0.2, height: 5 }, scene);
      mote.material = moteMat; mote.isPickable = false; mote.isVisible = false;
      glow.referenceMeshToUseItsOwnMaterial(mote);
      return { slot: slot.slot, busy: false, work: false, from: home, to: home, t: 1, speed: 0, hover: k * 1.7, line: LINES[k % LINES.length], mote };
    });
    const ringCell = (rank: number) => { const r = ring[rank]; return r ? r.i : home; };
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
    const modelInstances = new Map<ModelKey, { mesh: Mesh; footprint: number; base: number; height: number; width: number; depth: number }>();
    const placeModel = (t: { mesh: Mesh; footprint: number; base: number }, matrices: number[], target: number, scales: number[] = [], turns: number[] = [], heights: number[] = [], colors: number[] = []) => {
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
    };
    void (async () => {
      const keys: ModelKey[] = ["backlog", "running", "review", "done", "doneDepot", "doneSilo", "blocked", "dropped", "plinth", "walls", "tower", "wizardTower", "keep", "unitTower"];
      const loaded = await Promise.all(keys.map(async (key) => [key, await loadTemplate(scene, key)] as const));
      const missing = loaded.filter(([, t]) => !t).map(([k]) => k);
      host.setAttribute("data-models", `${loaded.length - missing.length}/${loaded.length}`);
      if (missing.length > 0) host.setAttribute("data-model-error", missing.join(",")); else host.removeAttribute("data-model-error");
      if (disposed || scene.isDisposed) { for (const [, t] of loaded) t?.mesh.dispose(); return; }
      for (const [key, t] of loaded) if (t) { modelInstances.set(key, t); if (["plinth", "wall", "walls", "tower", "wizardTower", "keep", "unitTower"].includes(key)) t.mesh.parent = layerNodes.castle; else if (!["hub", "crystal", "scribe", "wright", "lapidary", "larva"].includes(key)) t.mesh.parent = layerNodes.code; }
      const bind = (key: ModelKey, tpl: Template, target: number) => { const t = modelInstances.get(key); if (t) placeModel(t, tpl.matrices, target, tpl.scales, tpl.turns, tpl.heights, tpl.colors); };
      // a building takes about half a cell, so the roads between them still show
      // every Hexagon Kit building carries its own hex base, so a settlement is
      // scaled to the cell, not to a fraction of it: one cell, one tile, one roof
      const CELL_FIT = S_CELL * 0.94;
      bind("backlog", templates.backlog, CELL_FIT); bind("running", templates.running, CELL_FIT); bind("review", templates.review, CELL_FIT);
      bind("done", templates.done, CELL_FIT); bind("doneDepot", doneDepot, CELL_FIT); bind("doneSilo", doneSilo, CELL_FIT);
      bind("blocked", templates.blocked, CELL_FIT); bind("dropped", templates.dropped, CELL_FIT);
      // ---- the foundation: one cell per closed GitHub issue, drawn as an outline (the user, 2026-09-06) ----
      // Every hexagon on the field IS a GitHub issue: no filled tile, no honey disc, only the cell's border.
      // A cell that carries a closed issue burns in its age's gold (honeyTone); an empty cell is a dim wax line.
      host.setAttribute("data-tile", "outline");
      host.setAttribute("data-hex-orient", "pointy");
      try {
        if (cells.length > 1) {
          const lines: Vector3[][] = []; const lineColours: Color4[][] = [];
          let count = 0; let first: string | null = null; let last: string | null = null;
          for (let i = 1; i < cells.length; i += 1) {
            const corners = hexCornersAt(cells[i].x, cells[i].y, HEX_R, 4);
            lines.push([...corners, corners[0]].map((c) => new Vector3(c.x, 1.5, c.y)));
            const issue = fCells?.[i] ?? null;
            const tone = issue ? honeyTone(issue.closedAt, nowWall) : [0.24, 0.3, 0.28, 1];
            const c4 = new Color4(tone[0], tone[1], tone[2], issue ? 0.95 : 0.28);
            lineColours.push(Array.from({ length: 7 }, () => c4));
            if (issue) { const a = spiralAxial(i); const tag = `${issue.number}@${a.q},${a.r}`; if (first === null) first = tag; last = tag; count += 1; }
          }
          const comb = CreateLineSystem("cells", { lines, colors: lineColours, useVertexAlpha: true }, scene);
          comb.isPickable = false; comb.parent = layerNodes.foundation; comb.alwaysSelectAsActiveMesh = true;
          glow.referenceMeshToUseItsOwnMaterial(comb);
          host.setAttribute("data-foundation-shape", "outline");
          host.setAttribute("data-foundation-cells", String(count));
          host.setAttribute("data-foundation-shown", layersRef.current.foundation ? String(count) : "0");
          if (first) host.setAttribute("data-foundation-first", first);
          if (last) host.setAttribute("data-foundation-last", last);
        }
      } catch (e) {
        // the field reports its own failure instead of drawing nothing silently
        host.setAttribute("data-foundation-error", e instanceof Error ? e.message : String(e));
      }
      // ---- the castle of the rings (K-2/K-3): a plinth per ring directory on spiral ring 7, a tower by the stage of its epics ----
      try {
        const plinthT = modelInstances.get("plinth");
        const rings = fdNow?.rings ?? [];
        if (fdNow && plinthT && rings.length > 0 && cells.length > hexRingStart(CASTLE_RING)) {
          const places = castlePlaces(rings).filter((pl) => pl.plinth < cells.length);
          const epics = fdNow.epics ?? [];
          const flatTopP = plinthT.width > plinthT.depth;
          const kp = (S_CELL * 0.92) / Math.min(plinthT.width, plinthT.depth);
          // the cells are outlines now, so a plinth stands on the plate itself
          const lift = 2;
          const pm: number[] = []; const pc: number[] = [];
          const stageOf = (ring: string): TowerStage => {
            const order: TowerStage[] = ["plinth", "walls", "tower", "wizardTower"];
            let best: TowerStage = "plinth";
            for (const e of epics) if (ringOfEpic(e, rings).ring === ring) { const st = towerStage(e); if (order.indexOf(st) > order.indexOf(best)) best = st; }
            return best;
          };
          const towerMats = new Map<TowerStage, number[]>();
          const stages: string[] = [];
          for (const pl of places) {
            const c = cells[pl.plinth];
            pm.push(...Matrix.Compose(new Vector3(kp, kp, kp), Quaternion.RotationAxis(Vector3.Up(), flatTopP ? Math.PI / 6 : 0), new Vector3(c.x, lift - plinthT.base * kp, c.y)).toArray());
            pc.push(...familyTint(ringFamily(pl.ring)));
            const st = stageOf(pl.ring);
            stages.push(`${pl.ring}:${st}`);
            if (st !== "plinth") {
              const summary = ringSummary(pl.ring, epics, rings);
              const h = 0.6 + 1.4 * (summary.ratio ?? 0);
              const list = towerMats.get(st) ?? [];
              list.push(...Matrix.Compose(new Vector3(1, h, 1), Quaternion.RotationAxis(Vector3.Up(), 0), new Vector3(c.x, lift + plinthT.height * kp, c.y)).toArray());
              towerMats.set(st, list);
            }
          }
          plinthT.mesh.parent = layerNodes.castle;
          placeModel(plinthT, pm, S_CELL * 0.92, places.map(() => 1), places.map(() => (flatTopP ? Math.PI / 6 : 0)), places.map(() => 1), pc);
          plinthT.mesh.position.y = lift; // placeModel lifts by -base*k; the plinth stands above the tile
          for (const [st, mats] of towerMats) {
            const key: ModelKey = st === "walls" ? "walls" : st === "tower" ? "tower" : "wizardTower";
            const t = modelInstances.get(key);
            if (!t) continue;
            t.mesh.parent = layerNodes.castle;
            const hs = Array.from({ length: mats.length / 16 }, (_, j) => mats[j * 16 + 5]);
            placeModel(t, mats, S_CELL * 0.6, hs.map(() => 1), hs.map(() => 0), hs, hs.flatMap(() => [1, 1, 1, 1]));
            t.mesh.position.y = lift + plinthT.height * kp;
          }
          const unassigned = epics.filter((e) => ringOfEpic(e, rings).ring === null).length;
          // the keep at the hub (K-4): the castle's heart on its own layer; the unassigned epics stand around it as small towers
          const keepT = modelInstances.get("keep");
          if (keepT) {
            keepT.mesh.parent = layerNodes.castle;
            placeModel(keepT, [...Matrix.Translation(cells[home].x, 0, cells[home].y).toArray()], S_CELL * 1.05);
            host.setAttribute("data-castle-keep", "1");
            // the unassigned epics were drawn at radius 93 inside the keep's 112.5
            // reach, so nobody ever saw them (V-6): the count testifies instead
          }
          // the ring names live in the hover card and the panel, not as billboards
          // over the comb (V-4): the count still testifies, nothing occludes
          host.setAttribute("data-castle-plates", String(places.length));
          // the ring's own cells (K-5) are named by the hover link and the panel.
          // The mark discs were flat-top hexes on a pointy-top grid, 30 degrees off
          // every one, and a filled tile on a field pinned as outlines (V-3).
          const cellsOfRing = new Map<string, number[]>();
          cards.forEach((cd, ci) => { if (!cd) return; const rn = ringOfModulePath(cd.title); if (rn && rings.includes(rn)) cellsOfRing.set(rn, [...(cellsOfRing.get(rn) ?? []), ci]); });
          host.setAttribute("data-castle-marks", String([...cellsOfRing.values()].reduce((n, l) => n + l.length, 0)));
          castleLinks = { plinthOfRing: new Map(places.map((pl) => [pl.ring, pl.plinth])), ringOfCell: new Map(places.map((pl) => [pl.plinth, pl.ring])), cellsOfRing, epics, rings };
          // the release tags belong in the HUD, not on 19px flags (V-5)
          const releases = fdNow.releases ?? [];
          host.setAttribute("data-castle-banners", String(Math.min(releases.length, 8)));
          host.setAttribute("data-castle-rings", String(places.length));
          host.setAttribute("data-castle-stages", stages.sort().join(";"));
          host.setAttribute("data-castle-unassigned", String(unassigned));
          host.setAttribute("data-castle-releases", String((fdNow.releases ?? []).length));
        }
      } catch (e) {
        host.setAttribute("data-castle-error", e instanceof Error ? e.message : String(e));
      }
      // the throne: the Queen's castle at the hub, on no layer, always visible
      const keepT = modelInstances.get("keep");
      if (keepT) { keepT.mesh.parent = null; placeModel(keepT, [...Matrix.Translation(cells[home].x, 0, cells[home].y).toArray()], S_CELL * 1.05); host.setAttribute("data-castle-keep", "1"); }
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
      const p = groundAt(x, y);
      return p ? hexIndexAt(p.x, p.z, cells.length) : -1;
    };
    let hover = -1;
    // the roots (K-5): a picked closed issue that an epic lists draws lines from the epic's tower (the keep when unassigned) to every closed child on the field
    const drawRoots = (number: number | null) => {
      if (rootLines) { rootLines.dispose(); rootLines = null; }
      host.removeAttribute("data-castle-roots");
      if (number === null || !castleLinks || !fCells) return;
      const epic = epicOfIssue(number, castleLinks.epics);
      if (!epic) return;
      const ringName = ringOfEpic(epic, castleLinks.rings).ring;
      const from = ringName !== null ? castleLinks.plinthOfRing.get(ringName) ?? home : home;
      const top = new Vector3(cells[from].x, S * 0.5, cells[from].y);
      const lines: Vector3[][] = [];
      for (const ch of epic.children) { if (ch.state !== "closed") continue; const ci = fCells.findIndex((f) => f?.number === ch.number); if (ci < 0) continue; lines.push([top, new Vector3(cells[ci].x, 3, cells[ci].y)]); }
      if (lines.length > 0) { rootLines = CreateLineSystem("roots", { lines }, scene); rootLines.color = new Color3(1, 0.86, 0.4); rootLines.alpha = 0.9; rootLines.isPickable = false; rootLines.parent = layerNodes.castle; }
      host.setAttribute("data-castle-roots", `${epic.number}:${lines.length}`);
    };
    let downAt: [number, number] | null = null;
    let travelled = 0;
    scene.onPointerObservable.add((info) => {
      if (info.type === PointerEventTypes.POINTERDOWN) { downAt = [scene.pointerX, scene.pointerY]; travelled = 0; }
      if (info.type === PointerEventTypes.POINTERMOVE) {
        if (downAt) { travelled += Math.abs(scene.pointerX - downAt[0]) + Math.abs(scene.pointerY - downAt[1]); downAt = [scene.pointerX, scene.pointerY]; }
        else { hover = cellUnder(scene.pointerX, scene.pointerY); pointerXY = [scene.pointerX, scene.pointerY]; }
      }
      if (info.type === PointerEventTypes.POINTERUP) downAt = null;
    });
    canvas.addEventListener("click", (e) => {
      if (travelled > 6) { travelled = 0; return; }
      const rect = canvas.getBoundingClientRect();
      const index = cellUnder(e.clientX - rect.left, e.clientY - rect.top);
      if (index < 0) { host.setAttribute("data-hit", "off"); return; }
      const card = layersRef.current.code ? cards[index] : null;
      // the top visible layer wins (H-E): the hub, then a module with CODE on,
      // then a honey cell with FOUNDATION on; anything else is empty ground
      // (P1-10): the click clears the selection, as on an RTS map
      if (!card && index !== home) {
        const issue = fCells?.[index];
        if (issue && layersRef.current.foundation) {
          host.setAttribute("data-hit", "issue");
          drawRoots(issue.number);
          onPickRef.current?.({ index, isQueen: false, territory: cells[index].own, card: null, bee: null, kind: "issue", issue } as HudPick);
          return;
        }
        host.setAttribute("data-hit", "void"); drawRoots(null); onPickRef.current?.(null); return;
      }
      drawRoots(null);
      host.setAttribute("data-hit", index === home ? "queen" : "module");
      const b = beeAt(index);
      onPickRef.current?.({ index, isQueen: index === home, territory: cells[index].own, card: card ?? null, bee: b ? { slot: b.slot, line: b.line, busy: b.busy } : null, kind: index === home ? "queen" : "module" } as HudPick);
    });
    canvas.addEventListener("pointerleave", () => { hover = -1; showHoverCard(-1); });

    // ---- frame loop ---------------------------------------------------------
    const t0 = performance.now();
    let frames = 0;
    let lastMs = t0;
    engine.runRenderLoop(() => {
      const nowMs = performance.now();
      const dt = Math.min(nowMs - lastMs, 32); lastMs = nowMs;
      // the zoom glides instead of snapping, and it glides toward the cursor:
      // an orthographic frustum is a uniform scale about the target, so moving
      // the target by (1 - 1/f) toward the anchor keeps that point still
      if (zoom !== zoomGoal) {
        const prev = zoom;
        zoom = Math.abs(zoomGoal - zoom) < 1e-4 ? zoomGoal : zoom + (zoomGoal - zoom) * (1 - Math.pow(2, -dt / 60));
        const f = zoom / prev;
        if (anchor && f !== 1) {
          const k = 1 - 1 / f;
          camera.target.x += (anchor.x - camera.target.x) * k;
          camera.target.z += (anchor.z - camera.target.z) * k;
          clampTarget();
        }
        fit();
      }
      // The box can change while no frame runs (a hidden pane, fullscreen,
      // a pane resized before it is shown); a ResizeObserver alone missed
      // that and left the field clipped to the old canvas. Check every frame.
      const cw = canvas.clientWidth, ch = canvas.clientHeight;
      if ((cw > 0 && ch > 0) && (canvas.width !== cw || canvas.height !== ch)) { engine.resize(); fit(); }
      if (insetRef.current !== appliedInset) fit();
      // the layers: applied on change, no rebuild; the host mirrors the applied state
      const want = layersRef.current;
      let changed = false;
      for (const k of FIELD_LAYERS) { if (layerNodes[k].isEnabled(false) !== want[k]) { layerNodes[k].setEnabled(want[k]); changed = true; } }
      if (changed || frames === 0) { host.setAttribute("data-layers", FIELD_LAYERS.filter((k) => want[k]).join(",") || "none"); const fc = host.getAttribute("data-foundation-cells"); if (fc !== null) host.setAttribute("data-foundation-shown", want.foundation ? fc : "0"); }
      aimBees();
      bees.forEach((b, k) => {
        if (b.t < 1) b.t = Math.min(1, b.t + (b.speed * dt) / 1000);
        const A = cells[b.from], B = cells[b.to];
        if (!A || !B) return;
        const e = b.t < 0.5 ? 2 * b.t * b.t : 1 - 2 * (1 - b.t) * (1 - b.t);
        let x = A.x + (B.x - A.x) * e, z = A.y + (B.y - A.y) * e;
        if (b.t >= 1 && b.busy) { const ph = nowMs / 700 + b.hover; x = B.x + Math.cos(ph) * S * 0.12; z = B.y + Math.sin(ph * 1.3) * S * 0.08; }
        b.mote.isVisible = true;
        b.mote.position.set(x, 4 + (b.busy ? Math.abs(Math.sin(nowMs / 140 + k)) * 4 : 0), z);
        b.mote.scaling.setAll(b.busy ? 1 : 0.62);
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
      // a hovered plinth (K-5) draws the link from the ring's stone to the module cells it owns; nothing is drawn for a ring that owns no placed module
      const linkRing = hover >= 0 && layersRef.current.castle && castleLinks ? castleLinks.ringOfCell.get(hover) ?? null : null;
      if (linkRing !== linkFor) {
        if (linkLines) { linkLines.dispose(); linkLines = null; }
        linkFor = linkRing;
        if (linkRing && castleLinks) {
          const owned = castleLinks.cellsOfRing.get(linkRing) ?? [];
          const from = new Vector3(cells[hover].x, S * 0.35, cells[hover].y);
          if (owned.length > 0) { linkLines = CreateLineSystem("ring-link", { lines: owned.map((ci) => [from, new Vector3(cells[ci].x, 4, cells[ci].y)]) }, scene); const tint = familyTint(ringFamily(linkRing)); linkLines.color = new Color3(tint[0], tint[1], tint[2]); linkLines.alpha = 0.85; linkLines.isPickable = false; linkLines.parent = layerNodes.castle; }
          host.setAttribute("data-castle-link", `${linkRing}:${owned.length}`);
        } else host.removeAttribute("data-castle-link");
      }
      // no hover ring on empty ground (P1-10): only modules and the Queen's hub answer the pointer
      if (hover >= 0 && hover !== p && cells[hover] && ((layersRef.current.code && cards[hover]) || hover === home || (layersRef.current.foundation && fCells?.[hover]))) placeDashed(hover, 1.4); else hovered.isVisible = false;
      showHoverCard(layersRef.current.foundation && hover >= 0 ? hover : -1);
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
      canvas.removeEventListener("wheel", onWheel);
      canvas.removeEventListener("pointerdown", onDown);
      canvas.removeEventListener("pointermove", onMove);
      canvas.removeEventListener("pointerup", onUp);
      canvas.removeEventListener("pointercancel", onUp);
      ro.disconnect(); engine.stopRenderLoop(); scene.dispose(); engine.dispose();
    };
  }, [signature]);

  return (
    <div className="queen27-comb is-embedded is-babylon">
      <div className="queen27-comb-field" ref={hostRef} data-engine="babylon" data-look="platform" data-grid="hex">
        <canvas ref={canvasRef} style={{ touchAction: "none", outline: "none" }} />
        <div className="queen27-hover-card" ref={cardRef} aria-hidden="true" />
      </div>
    </div>
  );
}
