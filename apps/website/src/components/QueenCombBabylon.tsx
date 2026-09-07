// The comb in Babylon.js as a HIVE DISPLAY (the user, 2026-09-06): a vertical
// honeycomb wall floating right in front of the player — not a board lying on
// the ground. No 3D models: every fact is a cell (rim, cap, colour, card).
// Cells rise toward the hand on hover and tap; the pointer is answered with
// honey. Issue fills show unresolved goals (red), work/review (blue), and
// completed T27 goals (honey). Module provenance is a separate law. The logo
// inside the hub cell — and the latest wire events land in their cells as
// cards, so the comb works as the hive's display.
import { ImageProcessingConfiguration } from "@babylonjs/core/Materials/imageProcessingConfiguration";
import { useEffect, useRef, useState, useImperativeHandle } from "react";
import { QueenHiveDisplays, QueenHiveTaskLegend, type HiveDisplayController } from './QueenHiveDisplays';
import { QueenStarfield } from './QueenStarfield';
import {catalogCellAt,catalogFocusView,catalogSpecSelection,catalogConnectionView,type CatalogHive,type CatalogController} from './queenCatalogData';
import { HIVE_TASK_PALETTE, hiveSignalDelivery, hiveSignalRing, hiveRunningIssueNumbers, hiveTaskPaint, hiveTaskCounts, hiveDisplayPaintKey, hiveFocusZoom, hiveDisplayLod, type HiveDisplay, type HiveDisplayProjection, type HiveTaskTone, type HiveSignalHealth, type HiveSignalCursor, type HiveEventRing } from './queenHiveDisplay';
import { HIVE_WALL_ROTATION, hiveWallToWorld, hiveWorldToWall } from './queenHiveOrientation';
import type { Ref } from "react";
import { TransformNode } from "@babylonjs/core/Meshes/transformNode";
import { Engine } from "@babylonjs/core/Engines/engine";
import { Scene } from "@babylonjs/core/scene";
import { ArcRotateCamera } from "@babylonjs/core/Cameras/arcRotateCamera";
import { Camera } from "@babylonjs/core/Cameras/camera";
import { Vector3, Matrix } from "@babylonjs/core/Maths/math.vector";
import { Color3, Color4 } from "@babylonjs/core/Maths/math.color";
import { Mesh } from "@babylonjs/core/Meshes/mesh";
import { VertexBuffer } from "@babylonjs/core/Buffers/buffer";
import { StandardMaterial } from "@babylonjs/core/Materials/standardMaterial";
import { CreateLineSystem, CreateDashedLines } from "@babylonjs/core/Meshes/Builders/linesBuilder";
import { CreateCylinder } from "@babylonjs/core/Meshes/Builders/cylinderBuilder";
import { HemisphericLight } from "@babylonjs/core/Lights/hemisphericLight";
import { DirectionalLight } from "@babylonjs/core/Lights/directionalLight";
import "@babylonjs/core/Lights/Shadows/shadowGeneratorSceneComponent";
import { GlowLayer } from "@babylonjs/core/Layers/glowLayer";
import "@babylonjs/core/Layers/effectLayerSceneComponent";
import "@babylonjs/core/Meshes/thinInstanceMesh";
import type { LinesMesh } from "@babylonjs/core/Meshes/linesMesh";
import { PointerEventTypes } from "@babylonjs/core/Events/pointerEvents";
import { Ray } from "@babylonjs/core/Culling/ray";
import { S, EDGES } from "./QueenComb";
import { eventTone, ringTone, type BeeLine, type HudEvent, type HudModule, type HudPick, type Tone , eventIdentity , hexCellSummaries, hexIndexAt, hexCornersAt, HEX_HOME, HEX_R, foundationCells, spiralAxial, S_CELL, type FoundationIssue,
 FIELD_LAYERS, type FieldLayer, type CombHandle,
 castlePlaces, ringOfEpic, towerStage, ringFamily, familyTint, ringOfModulePath, epicOfIssue, type TowerStage, type EpicRecord,
 HIVE_TONES, hiveCoverOf, hiveToneOf, type HiveCover,
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
  sceneKey?: string;
  inspectIssueKey?: string | null;
  inspectCatalogKey?: string | null;
  onDisplaySelect?: (row:HiveDisplay)=>void;
  /** A shared resource layer in this exact renderer; never coerced to issues. */
  catalogLayer?: CatalogHive;
  catalogControlRef?: Ref<CatalogController>;
  onCatalogPick?: (index:number|null)=>void;
  onCatalogProject?: (rows:HiveDisplayProjection[],regions:HiveDisplayProjection[])=>void;
  signalHealth?: HiveSignalHealth;
  displays?: readonly (HiveDisplay | null)[];
  lang?: 'ru' | 'en';
  onInspect?: () => void;
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
  /** Per issue in progress: its exact issue display cell, or null (unmapped). */
  beeTargets?: ReadonlyArray<number | null>;
  /** The honeycomb foundation: the loop's snapshot of closed GitHub issues, one honey hex each. */
  foundation?: { issues: FoundationIssue[]; generatedAt: string; source: "wire" | "file"; rings?: string[]; epics?: EpicRecord[]; releases?: Array<{ tag: string; name: string; publishedAt: string | null; prerelease: boolean }> } | null;
  /** Which layers draw: FOUNDATION (tiles and honey), CASTLE (the rings' towers), CODE (the module buildings). Bees always. */
  layers?: Record<FieldLayer, boolean>;
  /** The toolbar's zoom and fit, the same handle the canvas comb exposes. */
  handleRef?: Ref<CombHandle>;
  /** Exact paths claimed by the displayed repository's T27 corpus; null is unknown. */
  t27Coverage?: ReadonlySet<string> | null;
  /** The colour law's words, in the page's language, for the legend above the field. */
  law?: { t27: string; manual: string; awaiting: string; unknown: string; bees: string };
}

type Territory = "held" | "neutral" | "fog";
const LINES: readonly BeeLine[] = ["scribe", "wright", "lapidary"];
const TONE_HEX: Record<Tone, string> = { gold: "#FFD45A", cold: "#FF6B6B", green: "#00FF88", cyan: "#64DCFF", muted: "#FFFFFF" };
const EMPTY_EVENTS: HudEvent[] = [];
const RING_POOL = 24;



const ALL_LAYERS: Record<FieldLayer, boolean> = { foundation: true, castle: true, code: true };
const UNKNOWN_HEALTH: HiveSignalHealth = {board:'unknown',activity:'unknown'};

export function QueenCombBabylon({ cards, workers, onPick, pickIndex = null, fitInset = 0, events = EMPTY_EVENTS, modules, beeTargets, foundation = null, layers = ALL_LAYERS, handleRef, t27Coverage = null, law, displays, lang = 'en', onInspect, signalHealth = UNKNOWN_HEALTH, catalogLayer,catalogControlRef,onCatalogPick,onCatalogProject,sceneKey='default',inspectIssueKey,inspectCatalogKey,onDisplaySelect }: QueenCombBabylonProps) {
  const catalogRef=useRef(catalogLayer),catalogPickRef=useRef(onCatalogPick),catalogProjectRef=useRef(onCatalogProject),catalogController=useRef<CatalogController|null>(null);
  useEffect(()=>{catalogRef.current=catalogLayer;catalogPickRef.current=onCatalogPick;catalogProjectRef.current=onCatalogProject;},[catalogLayer,onCatalogPick,onCatalogProject]);
  useImperativeHandle(catalogControlRef,()=>({inspect:(index,focus)=>catalogController.current?.inspect(index,focus),overview:()=>catalogController.current?.overview(),hover:index=>catalogController.current?.hover(index)}),[]);
  const hostRef = useRef<HTMLDivElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const cardRef = useRef<HTMLDivElement>(null);
  const [projections, setProjections] = useState<HiveDisplayProjection[]>([]);
  const [selectedDisplayKey, setSelectedDisplayKey] = useState<string | null>(null);
  const displayIndex = displays?.findIndex(row => row?.key === selectedDisplayKey) ?? -1;
  const selectedDisplay = displayIndex >= 0 ? displayIndex : null;
  const displaysRef = useRef(displays);
  const selectedDisplayRef = useRef(selectedDisplay);
  const inspectRef = useRef(onInspect);
  const displayControllerRef = useRef<HiveDisplayController | null>(null);
  const appliedIssueFocus=useRef<string|null>(null);
  const appliedCatalogFocus=useRef<string|null>(null);
  const savedViewRef = useRef<{ zoom: number; x: number; y: number; focusKey: string | null; connection?:boolean } | null>(null);
  const savedViewsRef = useRef(new Map<string,NonNullable<typeof savedViewRef.current>>());
  const displaySelectRef=useRef(onDisplaySelect);
  useEffect(()=>{displaySelectRef.current=onDisplaySelect;},[onDisplaySelect]);
  useEffect(() => { displaysRef.current = displays; selectedDisplayRef.current = selectedDisplay; inspectRef.current = onInspect; }, [displays, selectedDisplay, onInspect]);
  const onPickRef = useRef(onPick);
  const pickRef = useRef<number | null>(pickIndex);
  const insetRef = useRef(fitInset);
  const eventsRef = useRef(events);
  const signalHealthRef = useRef(signalHealth);
  const signalCursorRef = useRef<HiveSignalCursor>({ready:false,seen:new Set()});
  const displayRepo = displays?.find(row=>row!==null)?.repo;
  useEffect(()=>{signalCursorRef.current={ready:false,seen:new Set()};},[displayRepo]);
  useEffect(()=>{signalHealthRef.current=signalHealth;},[signalHealth]);
  const seenEventsRef = useRef<Set<string>>(new Set());
  const eventsPrimedRef = useRef(false);
  useEffect(() => {
    onPickRef.current = onPick;
    pickRef.current = pickIndex;
    insetRef.current = fitInset;
    eventsRef.current = events;
  }, [onPick, pickIndex, fitInset, events]);

  const signature = JSON.stringify([
    catalogLayer?.signature??null,
    cards.map((c) => (c ? [c.number, c.column] : null)),
    workers?.slots.map((s) => [s.slot, s.state]) ?? null,
    // a new snapshot of the foundation rebuilds the honey like a modules change rebuilds the city
    foundation ? [foundation.generatedAt, foundation.issues.length] : null,
    hiveDisplayPaintKey(displays),
    // a new claim from the spec corpus re-colours the law; the words re-word the legend
    t27Coverage ? [...t27Coverage].sort() : null,
    law ? [law.t27, law.manual, law.awaiting, law.unknown, law.bees] : null,
  ]);
  const cardsRef = useRef(cards);
  const workersRef = useRef(workers);
  const modulesRef = useRef(modules);
  const targetsRef = useRef(beeTargets);
  const foundationRef = useRef(foundation);
  const layersRef = useRef(layers);
  const coverageRef = useRef(t27Coverage);
  const lawRef = useRef(law);
  const cameraRef = useRef<CombHandle | null>(null);
  useEffect(() => {
    cardsRef.current = cards;
    workersRef.current = workers;
    modulesRef.current = modules;
    targetsRef.current = beeTargets;
    foundationRef.current = foundation;
    layersRef.current = layers;
    coverageRef.current = t27Coverage;
    lawRef.current = law;
  }, [cards, workers, modules, beeTargets, foundation, layers, t27Coverage, law]);

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
    const viewKey=(index:number)=>displaysRef.current?.[index]?.key??catalogRef.current?.cells[index]?.key??null;
    const viewStore=savedViewsRef.current;
    savedViewRef.current=viewStore.get(sceneKey)??null;
    const cellScale=(index:number)=>catalogRef.current?.positions?.[index]?.scale??1;
    const cells = hexCellSummaries(cards).map((cell,index)=>{
      const position=catalogRef.current?.positions?.[index];
      return position?{...cell,x:position.x,y:position.y,yTop:position.y-HEX_R*position.scale}:cell;
    });
    const home = HEX_HOME;
    // the honey under the cells (H-C2): the same map the click reads (H-E)
    const fdNow = foundationRef.current;
    const fCells = fdNow ? foundationCells(fdNow.issues, cells.length) : null;
    // the castle's testimony starts honest: no snapshot, no castle facts
    host.setAttribute("data-castle-source", fdNow ? fdNow.source : "none");
    if (!fdNow) { host.removeAttribute("data-castle-stages"); host.removeAttribute("data-castle-rings"); host.removeAttribute("data-castle-unassigned"); host.removeAttribute("data-castle-releases"); }
    const engine = new Engine(canvas, true, { preserveDrawingBuffer: false, stencil: false }, false);
    // Sharpness (the user, 2026-09-06: "сделай качество выше"). The engine was
    // rendering one sample per CSS pixel, so on a 2x display every line on the
    // comb was drawn at half the resolution of the screen it lands on. Capped at
    // 2x: past that the comb costs four times the pixels for nothing the eye
    // gets. Babylon's own picking divides by the same scaling level, so the pan,
    // the wheel and the pick keep working - proved by the pick, void and touch
    // gates rather than assumed.
    engine.setHardwareScalingLevel(1 / Math.min(2, Math.max(1, window.devicePixelRatio || 1)));
    const scene = new Scene(engine);
    const motionPreference = window.matchMedia('(prefers-reduced-motion: reduce)');
    scene.clearColor = new Color4(0, 0, 0, 0);
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
    // a tighter, dimmer bloom: at kernel 24 the centre of the comb smeared into
    // one haze because a thousand lit rims bled into each other
    const glow = new GlowLayer("glow", scene, { blurKernelSize: 12 });
    glow.intensity = 0.42;

    // ---- extents and the floating wall: vertical, facing the player ------
    let minX = Infinity, maxX = -Infinity, minZ = Infinity, maxZ = -Infinity;
    cells.forEach((c,index) => {
      const scale=cellScale(index);
      minX = Math.min(minX, c.x - S_CELL*scale / 2); maxX = Math.max(maxX, c.x + S_CELL*scale / 2);
      minZ = Math.min(minZ, c.y - HEX_R*scale); maxZ = Math.max(maxZ, c.y + HEX_R*scale);
    });
    const centre = new Vector3((minX + maxX) / 2, 0, (minZ + maxZ) / 2);
    // THE WALL (the user, 2026-09-06: "поле не по горизонтали лежащим, а прямо
    // перед лицом парящее"). The comb keeps its own flat coordinates (x, z per
    // cell, y as height toward the board); one root turns that plane into the
    // wall the player faces. After the user's180-degree field turn, local
    // (x, height, z) becomes world (-x, z, height). The original SVG mark now
    // projects point-down, without changing its geometry or mirroring it. The
    // camera sits dead in front at +Z, so the honeycomb hangs in the air at eye
    // height and a cell's lift (its local y) comes TOWARD the hand instead of
    // away from it. Every position below stays in comb coordinates; only the
    // pick and the pan convert world to comb.
    const fieldRoot = new TransformNode("field-root", scene);
    fieldRoot.rotation.copyFromFloats(HIVE_WALL_ROTATION.x, HIVE_WALL_ROTATION.y, HIVE_WALL_ROTATION.z);
    host.setAttribute('data-map-turn', '180');
    host.setAttribute('data-logo-orientation', 'point-down');
    const centrePoint = hiveWallToWorld(centre.x, centre.z);
    const centreWorld = new Vector3(centrePoint.x, centrePoint.y, 0);
    const camera = new ArcRotateCamera("cam", Math.PI / 2, Math.PI / 2, 4000, centreWorld.clone(), scene);
    // the wall is a plane, not a mesh: a screen point becomes a comb point by
    // solving the picking ray against z = 0, the plane the comb is drawn on
    const pickRay = new Ray(Vector3.Zero(), Vector3.Up(), Number.MAX_VALUE);
    const planeAt = (x: number, y: number): { x: number; z: number } | null => {
      scene.createPickingRayToRef(x, y, null, pickRay, camera);
      const dz = pickRay.direction.z;
      if (Math.abs(dz) < 1e-6) return null;
      const t = -pickRay.origin.z / dz;
      if (t < 0) return null;
      const wx = pickRay.origin.x + pickRay.direction.x * t;
      const wy = pickRay.origin.y + pickRay.direction.y * t;
      return hiveWorldToWall(wx, wy, fieldRoot.position.y);
    };
    const depth = Math.max(maxX - minX, maxZ - minZ);
    scene.fogStart = 4000 - depth * 0.1;
    scene.fogEnd = 4000 + depth * 1.4;
    camera.mode = Camera.ORTHOGRAPHIC_CAMERA;
    camera.lowerBetaLimit = Math.PI / 2; camera.upperBetaLimit = Math.PI / 2;
    camera.lowerAlphaLimit = camera.alpha; camera.upperAlphaLimit = camera.alpha;
    camera.panningSensibility = 0;
    let zoom = savedViewRef.current?.zoom ?? 1;
    let zoomGoal = zoom;
    if (savedViewRef.current) { camera.target.x = savedViewRef.current.x; camera.target.y = savedViewRef.current.y; }
    const restoredFocus = savedViewRef.current?.focusKey ? cells.findIndex((_,index)=>viewKey(index)===savedViewRef.current?.focusKey) : -1;
    let focusIndex: number | null = restoredFocus >= 0 ? restoredFocus : null;
    let focusConnection=savedViewRef.current?.connection??false;
    let anchor: { x: number; z: number } | null = null;
    let appliedInset = -1;
    // the castle's couplings to the code and the honey (K-5): filled when the snapshot lands
    let castleLinks: { plinthOfRing: Map<string, number>; ringOfCell: Map<number, string>; cellsOfRing: Map<string, number[]>; epics: EpicRecord[]; rings: string[] } | null = null;
    let linkLines: LinesMesh | null = null; let linkFor: string | null = null;
    let rootLines: LinesMesh | null = null;
    // three transform nodes carry the layers: a disabled parent hides its children without touching a buffer
    const layerNodes = Object.fromEntries(FIELD_LAYERS.map((layer) => {
      const node = new TransformNode(`layer-${layer}`, scene);
      node.parent = fieldRoot;
      return [layer, node];
    })) as Record<FieldLayer, TransformNode>;
    const specInset=()=>{
      const w=host.clientWidth||1,h=host.clientHeight||1;
      const mapHeight=host.closest('.queen-catalog-layer')?.clientHeight??h;
      return w>=700?{right:Math.min(.7,392/w),bottom:0}:{right:0,bottom:Math.min(.8,(mapHeight*.6+32)/h)};
    };
    const fit = () => {
      const w = host.clientWidth || 1, h = host.clientHeight || 1;
      const inset = insetRef.current;
      const band = h * (1 - inset);
      // the wall is parallel to the screen: width and height map one to one
      const portalMargin=catalogRef.current?Math.max(w/Math.max(100,w-160),band/Math.max(100,band-110)):1;
      const fieldW = (maxX - minX + S) * 1.04*portalMargin, fieldH = (maxZ - minZ + S) * 1.08*portalMargin;
      const aspect = w / band;
      let halfW = fieldW / 2, halfH = halfW / aspect;
      if (halfH < fieldH / 2) { halfH = fieldH / 2; halfW = halfH * aspect; }
      if (focusIndex !== null && cells[focusIndex]) {
        const view=catalogRef.current?(focusConnection?catalogConnectionView(catalogRef.current,focusIndex,halfW,halfH,specInset()):catalogFocusView(catalogRef.current,focusIndex,halfW,halfH,w,band,catalogRef.current.cells[focusIndex]?.kind==='spec'?specInset():undefined)):null;
        zoom = zoomGoal = view?.zoom??hiveFocusZoom(S_CELL * cellScale(focusIndex) * w / (halfW * 2), w, band);
        const focusedPoint = hiveWallToWorld(view?.x??cells[focusIndex].x, view?.y??cells[focusIndex].y);
        camera.target.x = focusedPoint.x;
        camera.target.y = focusedPoint.y;
      }
      halfW /= zoom; halfH /= zoom;
      const unitsPerPx = (halfH * 2) / band;
      const shift = (h - band) * unitsPerPx;
      camera.orthoLeft = -halfW; camera.orthoRight = halfW;
      camera.orthoTop = halfH; camera.orthoBottom = -halfH - shift;
      appliedInset = inset;
      host.setAttribute("data-zoom", zoom.toFixed(2));
      savedViewRef.current = {zoom,x:camera.target.x,y:camera.target.y,focusKey:focusIndex !== null ? viewKey(focusIndex) : null,connection:focusConnection};
    };
    fit();
    // the wall answers the hand (the user, 2026-09-06). Both the drag and the
    // wheel work against the same z = 0 plane the pick uses, so the point under
    // the cursor is the point that follows it; pan runs in the wall's own axes.
    const ROAM = Math.max(maxX - minX, maxZ - minZ) * 0.55;
    const clampTarget = () => {
      camera.target.x = Math.min(Math.max(camera.target.x, centreWorld.x - ROAM), centreWorld.x + ROAM);
      camera.target.y = Math.min(Math.max(camera.target.y, centreWorld.y - ROAM), centreWorld.y + ROAM);
    };
    const onWheel = (e: WheelEvent) => {
      e.preventDefault();
      const r = canvas.getBoundingClientRect();
      focusIndex = null;
      anchor = planeAt(e.clientX - r.left, e.clientY - r.top);
      zoomGoal = Math.min(128, Math.max(0.05, zoomGoal * Math.exp(-e.deltaY * 0.0016)));
      host.setAttribute("data-zoom-goal", zoomGoal.toFixed(2));
    };
    canvas.addEventListener("wheel", onWheel, { passive: false });
    let grab: { x: number; y: number } | null = null;
    const onDown = (e: PointerEvent) => { if (e.button !== 0) return; grab = { x: e.clientX, y: e.clientY }; canvas.setPointerCapture(e.pointerId); };
    const onMove = (e: PointerEvent) => {
      if (!grab) return;
      focusIndex = null;
      const r = canvas.getBoundingClientRect();
      const a = planeAt(grab.x - r.left, grab.y - r.top), b = planeAt(e.clientX - r.left, e.clientY - r.top);
      if (a && b) {
        const from = hiveWallToWorld(a.x,a.z), to = hiveWallToWorld(b.x,b.z);
        camera.target.x += from.x - to.x; camera.target.y += from.y - to.y;
        clampTarget(); fit();
      }
      grab = { x: e.clientX, y: e.clientY };
    };
    const onUp = (e: PointerEvent) => { grab = null; if (canvas.hasPointerCapture(e.pointerId)) canvas.releasePointerCapture(e.pointerId); };
    canvas.addEventListener("pointerdown", onDown);
    canvas.addEventListener("pointermove", onMove);
    canvas.addEventListener("pointerup", onUp);
    canvas.addEventListener("pointercancel", onUp);
    // the toolbar's FIT VIEW / - / + reach the scene through the same handle the canvas comb exposes
    cameraRef.current = {
      zoomIn: () => { focusIndex = null; anchor = null; zoom = zoomGoal = Math.min(128, zoom * 1.25); fit(); },
      zoomOut: () => { focusIndex = null; anchor = null; zoom = zoomGoal = Math.max(0.05, zoom / 1.25); fit(); },
      // FIT VIEW is the way home: it undoes the roam as well as the zoom
      fit: () => { focusIndex = null; selectedDisplayRef.current = null; setSelectedDisplayKey(null); host.removeAttribute('data-display-selected'); anchor = null; zoom = zoomGoal = 1; camera.target.copyFrom(centreWorld); fit(); },
    };
    const inspectDisplay = (index: number) => {
      const row = displaysRef.current?.[index]; if (!row) return;
      selectedDisplayRef.current = index; setSelectedDisplayKey(row.key);
      if(catalogRef.current)catalogPickRef.current?.(index);
      displaySelectRef.current?.(row);
      focusIndex = index; focusConnection=false; anchor = null; inspectRef.current?.(); fit();
      host.setAttribute('data-display-selected', row.key);
    };
    displayControllerRef.current = { inspect: inspectDisplay, overview: () => cameraRef.current?.fit(), hover: index => { hover = index ?? -1; } };
    catalogController.current={inspect:(index,focus=false)=>{
      if(displaysRef.current?.[index]){inspectDisplay(index);return;}
      const row=catalogRef.current?.cells[index];if(!row)return;
      selectedDisplayRef.current=null;setSelectedDisplayKey(null);host.removeAttribute('data-display-selected');
      pickRef.current=index;catalogPickRef.current?.(index);
      focusIndex=index;focusConnection=!focus&&row.kind==='spec';anchor=null;fit();
      host.setAttribute('data-catalog-selected',row.key);
    },overview:()=>{cameraRef.current?.fit();pickRef.current=null;catalogPickRef.current?.(null);host.removeAttribute('data-catalog-selected');},hover:index=>{hover=index??-1;}};

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
    // ---- no buildings: the kit is gone, the cell IS the fact ---------------
    // (the user, 2026-09-06: "убери 3D объекты а то шума много"). The whole
    // Hexagon Kit block — templates, thin instances, per-column depots — went
    // with the GLBs; what remains is pure comb geometry.
    // the colour law's cover for a cell: T27 if the corpus claims the module,
    // manual if there is hand-written code and no claim, awaiting otherwise
    const covered = coverageRef.current;
    const coverOf = (i: number): HiveCover => displaysRef.current
      ? displaysRef.current[i]?.coverage ?? 'awaiting'
      : hiveCoverOf(cards[i]?.title ?? null, covered);
    const covers: HiveCover[] = cells.map((_, i) => coverOf(i));

    // ---- rings: picked (gold), hover (dashed, honey) --------------------
    const ring7 = () => [Array.from({ length: 7 }, () => new Vector3(0, 0, 0))];
    const picked = CreateLineSystem("picked", { lines: ring7(), updatable: true }, scene);
    picked.color = Color3.FromHexString(HIVE_TONES.hover); picked.isPickable = false; picked.parent = fieldRoot;
    // a cell's outline is its hexagon, inset a little so the ring reads as the cell's, not the neighbour's
    const hexOf = (i: number): [number, number][] => hexCornersAt(cells[i].x, cells[i].y, HEX_R*cellScale(i), 4*cellScale(i)).map((c) => [c.x, c.y]);
    const placeRing = (mesh: LinesMesh, i: number, y: number) => {
      const p = hexOf(i); const pts = [...p, p[0]];
      const buf = mesh.getVerticesData(VertexBuffer.PositionKind);
      if (!buf) return;
      pts.forEach(([px, pz], k) => { buf[k * 3] = px; buf[k * 3 + 1] = y; buf[k * 3 + 2] = pz; });
      mesh.updateVerticesData(VertexBuffer.PositionKind, buf);
      mesh.isVisible = true;
    };
    const hovered = CreateDashedLines("hover", { points: Array.from({ length: 7 }, (_, k) => new Vector3(Math.cos(k), 0, Math.sin(k))), dashSize: 3, gapSize: 2, dashNb: 60, updatable: true }, scene);
    hovered.alpha = 0.9; hovered.isPickable = false; hovered.isVisible = false; hovered.parent = fieldRoot;
    // the hover card (the user, 2026-09-06): the hovered cell's issue, named beside the pointer
    let hoverIssue = -1;
    let pointerXY: [number, number] = [0, 0];
    const clearHoverCard = () => {
      hoverIssue = -1;
      cardRef.current?.setAttribute("aria-hidden", "true");
      cardRef.current?.replaceChildren();
      host.removeAttribute("data-hover-issue");
    };
    // DOM survives a scene rebuild; the previous repo's coverage must not.
    clearHoverCard();
    const showHoverCard = (i: number) => {
      const card = cardRef.current;
      if (!card) return;
      const issue = i >= 0 ? fCells?.[i] ?? null : null;
      if (!issue) {
        if (hoverIssue !== -1) clearHoverCard();
        return;
      }
      if (issue.number !== hoverIssue) {
        hoverIssue = issue.number;
        const head = document.createElement("b"); head.textContent = `#${issue.number} ${issue.title}`;
        const meta = document.createElement("span");
        const cover = coverOf(i);
        const coverWord = lawRef.current?.[cover] ?? (cover === "unknown" ? "T27 coverage unknown" : cover);
        // A closed issue and a module share a cell position, not an identity.
        // Attribute the claim to its module explicitly, never to that issue.
        const modulePath = cards[i]?.title;
        meta.textContent = [issue.closedAt.slice(0, 16).replace("T", " "), ...issue.labels, ...(modulePath ? [`${modulePath}: ${coverWord}`] : [])].join(" \u00b7 ");
        meta.dataset.cover = cover;
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
      // honey, not territory: the hand is looking for nectar (the user,
      // 2026-09-06: "не цветом говна выделять карточку! я медоносным цветом!")
      hovered.color = Color3.FromHexString(HIVE_TONES.hover);
      hovered.isVisible = true;
    };

    // ---- no sprites: the Queen is the mark, the swarm is motes -----------
    // (the user, 2026-09-06: "а королева в центре наш логотип! это и есть
    // королева"). The portrait sprite went with the buildings; the mark in the
    // hub cell below IS the Queen.
    const ring = cells
      .map((c, i) => ({ i, d: (c.x - cells[home].x) ** 2 + (c.y - cells[home].y) ** 2 }))
      .filter((e) => e.i !== home)
      .sort((a, b) => a.d - b.d);

    const running = cells.map((c, i) => ({ c, i })).filter(({ i }) => cards[i]?.column === "running").map(({ i }) => i);
    const indexByNumber = new Map<number, number>();
    if (displaysRef.current) displaysRef.current.forEach((row,i) => { if(row) indexByNumber.set(row.number,i); });
    else cells.forEach((c, i) => { if (c.cardNumber !== null) indexByNumber.set(c.cardNumber, i); });
    // The swarm is anonymous by the server's decision, so every bee is the same
    // mote: one glowing hex, bright while it works. Three sprite costumes used
    // to imply a distinction the wire does not carry; cut 2026-09-06.
    const moteMat = new StandardMaterial("mote", scene);
    moteMat.diffuseColor = new Color3(0.5, 0.4, 0.14); moteMat.emissiveColor = new Color3(0.95, 0.74, 0.28); moteMat.specularColor = Color3.Black();
    interface Bee { slot: number; busy: boolean; work: boolean; from: number; to: number; t: number; speed: number; hover: number; line: BeeLine; mote: Mesh }
    const bees: Bee[] = (workers?.slots ?? []).map((slot, k) => {
      const mote = CreateCylinder(`bee-${slot.slot}`, { tessellation: 6, diameter: S * 0.2, height: 5 }, scene);
      mote.material = moteMat; mote.isPickable = false; mote.isVisible = false; mote.parent = fieldRoot;
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
        if (b.busy) {
          const byIssue = issueTargets ? issueTargets[busyRank] : undefined;
          const fallback = displaysRef.current ? undefined : running[busyRank];
          target = byIssue ?? fallback ?? home;
          b.work = (byIssue !== undefined && byIssue !== null) || fallback !== undefined;
          busyRank += 1;
        }
        else { b.work = false; target = ringCell(idleRank); idleRank += 1; }
        if (b.to !== target) { b.from = b.t < 0.5 ? b.from : b.to; b.to = target; b.t = 0; b.speed = b.busy ? 0.55 : 0.35; }
      }
    };
    aimBees();
    const beeAt = (index: number) => bees.find((b) => (b.t < 0.5 ? b.from : b.to) === index) ?? null;
    const flightLines = bees.map((b) => { const m = CreateDashedLines(`flight-${b.slot}`, { points: [new Vector3(0, 0, 0), new Vector3(1, 0, 1)], dashSize: 6, gapSize: 4, dashNb: 40, updatable: true }, scene); m.color = Color3.FromHexString(HIVE_TONES.awaiting); m.alpha = 0.55; m.isPickable = false; m.isVisible = false; m.parent = fieldRoot; return m; });

    // ---- the hive: everything is comb, nothing is a model --------------------
    // The user, 2026-09-06: "убери 3D объекты а то шума много", "замки не красиво
    // смотрятся, а соты мёд пчёлы классно читается", and a reference image of a
    // dark hexagon field with glowing edges. So the kit is gone. Every fact is a
    // cell: its rim, its cap, its colour. A hive has no towers.
    host.setAttribute("data-look", "hive");
    host.setAttribute("data-models", "0/0");
    host.setAttribute("data-orientation", "facing");
    // Full hex fills remain visible below text LOD. One batch per status color,
    // not a material/texture per issue. Empty cells and the hub receive no fill.
    const capBatches = new Map<HiveTaskTone | 'legacy', number[]>();
    const drawCaps = (tone: HiveTaskTone | 'legacy', matrices: number[]) => {
      const material = new StandardMaterial(`cap-${tone}`, scene);
      material.diffuseColor = Color3.Black(); material.specularColor = Color3.Black();
      material.disableLighting = true;
      material.emissiveColor = tone === 'legacy' ? new Color3(.055, .075, .072) : Color3.FromHexString(HIVE_TASK_PALETTE[tone].hex);
      material.alpha = tone === 'legacy' ? .08 : HIVE_TASK_PALETTE[tone].alpha;
      // Keep catalog faces transparent at every zoom; preserve the golden rims.
      if(tone==='honey'&&catalogRef.current)material.alpha=.035;
      const caps = CreateCylinder(`caps-${tone}`, { tessellation: 6, diameter: 2 * HEX_R * .92, height: 2 }, scene);
      const cb = caps.getBoundingInfo().boundingBox;
      if (cb.maximum.x - cb.minimum.x > cb.maximum.z - cb.minimum.z) { caps.rotation.y = Math.PI / 6; caps.bakeCurrentTransformIntoVertices(); }
      caps.material = material; caps.isPickable = false; caps.parent = layerNodes.foundation;
      caps.alwaysSelectAsActiveMesh = true;
      caps.thinInstanceSetBuffer("matrix", new Float32Array(matrices), 16, true);
      glow.addExcludedMesh(caps); // Broad fills must not bloom into adjacent task states.
    };
    // A cell RISES under the pointer and stays up while it is picked (the user,
    // 2026-09-06). This is the reference picture's raised hex, and it is the only
    // motion on the field that answers the hand rather than the wire.
    const liftMat = new StandardMaterial("lift", scene);
    liftMat.diffuseColor = Color3.Black(); liftMat.specularColor = Color3.Black();
    liftMat.emissiveColor = new Color3(0.1, 0.14, 0.135);
    liftMat.alpha = 0.14;
    const lift = CreateCylinder("lift", { tessellation: 6, diameter: 2 * HEX_R * 0.92, height: 3 }, scene);
    const lb = lift.getBoundingInfo().boundingBox;
    if (lb.maximum.x - lb.minimum.x > lb.maximum.z - lb.minimum.z) { lift.rotation.y = Math.PI / 6; lift.bakeCurrentTransformIntoVertices(); }
    lift.material = liftMat; lift.isPickable = false; lift.isVisible = false; lift.parent = fieldRoot;
    let liftIndex = -1; let liftY = 0;
    // ---- the comb: one cell per GitHub issue, rim by state ------------------
    try {
      if (cells.length > 1) {
        const lines: Vector3[][] = []; const lineColours: Color4[][] = [];
        let count = 0; let first: string | null = null; let last: string | null = null;
        for (let i = 1; i < cells.length; i += 1) {
          const corners = hexCornersAt(cells[i].x, cells[i].y, HEX_R*cellScale(i), 4*cellScale(i));
          lines.push([...corners, corners[0]].map((c) => new Vector3(c.x, 1.5, c.y)));
          const issue = displaysRef.current ? displaysRef.current[i] : fCells?.[i] ?? null;
          const resource=catalogRef.current?.cells[i];
          const paint = resource?{tone:resource.kind==='spec'?'honey' as const:resource.open===null?'paused' as const:resource.open>0?'problem' as const:'active' as const}:displaysRef.current ? hiveTaskPaint(displaysRef.current[i]) : null;
          const tint = paint ? Color3.FromHexString(HIVE_TASK_PALETTE[paint.tone].hex) : null;
          const tone = tint ? [tint.r, tint.g, tint.b] : issue ? hiveToneOf(covers[i]) : [0.11, 0.34, 0.33, 1];
          const c4 = new Color4(tone[0], tone[1], tone[2], issue||resource ? 0.95 : 0.34);
          lineColours.push(Array.from({ length: 7 }, () => c4));
          if (issue||resource) {
            const batch = paint?.tone ?? 'legacy';
            const matrices = capBatches.get(batch) ?? [];
            matrices.push(...Matrix.Scaling(cellScale(i),1,cellScale(i)).multiply(Matrix.Translation(cells[i].x, .6, cells[i].y)).toArray());
            capBatches.set(batch, matrices);
            const a = spiralAxial(i); const tag = `${resource?.key??issue?.number}@${a.q},${a.r}`;
            if (first === null) first = tag; last = tag; count += 1;
          }
        }
        const comb = CreateLineSystem("cells", { lines, colors: lineColours, useVertexAlpha: true }, scene);
        comb.isPickable = false; comb.parent = layerNodes.foundation; comb.alwaysSelectAsActiveMesh = true;
        glow.referenceMeshToUseItsOwnMaterial(comb);
        for (const [tone, matrices] of capBatches) drawCaps(tone, matrices);
        host.setAttribute("data-foundation-shape", displaysRef.current ? "status-filled" : "outline");
        if(catalogRef.current){const specs=catalogRef.current.cells.filter(c=>c?.kind==='spec');host.setAttribute('data-catalog-specs',String(new Set(specs.map(c=>c.specId)).size));host.setAttribute('data-catalog-source-specs',String(specs.filter(c=>c.placement==='source').length));host.setAttribute('data-catalog-repos',String(catalogRef.current.cells.filter(c=>c?.kind==='repo').length));}
        host.setAttribute("data-task-fill-counts", JSON.stringify(hiveTaskCounts(displaysRef.current ?? [])));
        host.setAttribute("data-task-fill-batches", String(capBatches.size));
        host.setAttribute("data-foundation-cells", String(count));
        host.setAttribute("data-foundation-shown", layersRef.current.foundation ? String(count) : "0");
        const law = { t27: covers.filter((v) => v === "t27").length, manual: covers.filter((v) => v === "manual").length, awaiting: covers.filter((v) => v === "awaiting").length };
        host.setAttribute("data-cover-t27", String(law.t27));
        host.setAttribute("data-cover-manual", String(law.manual));
        host.setAttribute("data-cover-awaiting", String(law.awaiting));
        host.setAttribute("data-cover-unknown", String(covers.filter((v) => v === "unknown").length));
        host.setAttribute("data-coverage-status", displaysRef.current || covered === null ? "unknown" : "source-claim");
        if (first) host.setAttribute("data-foundation-first", first);
        if (last) host.setAttribute("data-foundation-last", last);
      }
    } catch (e) {
      host.setAttribute("data-foundation-error", e instanceof Error ? e.message : String(e));
    }
    // ---- the rings of the hive: a frame per ring directory, drawn flat -------
    // A ring used to be a stone plinth carrying a tower. In a hive it is a FRAME:
    // the cells of spiral ring 7 wear their family's colour, and an epic's stage
    // sets how brightly the frame burns. No geometry, only the comb's own rim.
    try {
      const fdNow2 = foundationRef.current;
      host.setAttribute("data-castle-source", fdNow2 ? fdNow2.source : "none");
      if (fdNow2 && (fdNow2.rings?.length ?? 0) > 0) {
        const rings = fdNow2.rings ?? [];
        const epics = fdNow2.epics ?? [];
        const places = castlePlaces(rings);
        const stageOf = (ring: string): TowerStage => {
          const order: TowerStage[] = ["plinth", "walls", "tower", "wizardTower"];
          let best: TowerStage = "plinth";
          for (const e of epics) if (ringOfEpic(e, rings).ring === ring) { const st = towerStage(e); if (order.indexOf(st) > order.indexOf(best)) best = st; }
          return best;
        };
        const BURN: Record<TowerStage, number> = { plinth: 0.3, walls: 0.55, tower: 0.8, wizardTower: 1 };
        const fl: Vector3[][] = []; const fc: Color4[][] = []; const stages: string[] = [];
        for (const pl of places) {
          const c = cells[pl.plinth]; if (!c) continue;
          const st = stageOf(pl.ring); stages.push(`${pl.ring}:${st}`);
          const t = familyTint(ringFamily(pl.ring)); const b = BURN[st];
          const corners = hexCornersAt(c.x, c.y, HEX_R * 0.94, 0);
          fl.push([...corners, corners[0]].map((q) => new Vector3(q.x, 3, q.y)));
          const col = new Color4(t[0] * (0.4 + 0.6 * b), t[1] * (0.4 + 0.6 * b), t[2] * (0.4 + 0.6 * b), 0.45 + 0.55 * b);
          fc.push(Array.from({ length: 7 }, () => col));
        }
        if (fl.length > 0) {
          const frames = CreateLineSystem("frames", { lines: fl, colors: fc, useVertexAlpha: true }, scene);
          frames.isPickable = false; frames.parent = layerNodes.castle;
          glow.referenceMeshToUseItsOwnMaterial(frames);
        }
        const unassigned = epics.filter((e) => ringOfEpic(e, rings).ring === null).length;
        castleLinks = { plinthOfRing: new Map(places.map((pl) => [pl.ring, pl.plinth])), ringOfCell: new Map(places.map((pl) => [pl.plinth, pl.ring])), cellsOfRing: new Map(), epics, rings };
        const cellsOfRing = castleLinks.cellsOfRing;
        cards.forEach((cd, ci) => { if (!cd) return; const rn = ringOfModulePath(cd.title); if (rn && rings.includes(rn)) cellsOfRing.set(rn, [...(cellsOfRing.get(rn) ?? []), ci]); });
        host.setAttribute("data-castle-marks", String([...cellsOfRing.values()].reduce((n, l) => n + l.length, 0)));
        host.setAttribute("data-castle-plates", String(places.length));
        host.setAttribute("data-castle-banners", String(Math.min((fdNow2.releases ?? []).length, 8)));
        host.setAttribute("data-castle-rings", String(places.length));
        host.setAttribute("data-castle-stages", stages.sort().join(";"));
        host.setAttribute("data-castle-unassigned", String(unassigned));
        host.setAttribute("data-castle-releases", String((fdNow2.releases ?? []).length));
        host.setAttribute("data-castle-keep", "1");
      } else {
        host.removeAttribute("data-castle-stages"); host.removeAttribute("data-castle-rings");
        host.removeAttribute("data-castle-unassigned"); host.removeAttribute("data-castle-releases");
      }
    } catch (e) {
      host.setAttribute("data-castle-error", e instanceof Error ? e.message : String(e));
    }
    // ---- the Queen at the centre: the mark itself ----------------------------
    // The user, 2026-09-06: "а королева в центре наш логотип! это и есть королева"
    {
      // the mark sits INSIDE the hub cell (the user, 2026-09-06): the Queen is a
      // cell of the comb like every other fact, not a thing laid over it
      const k = S_CELL * 0.62;
      const markLines = EDGES.map(([ax, ay, bx, by]) => [
        new Vector3(cells[home].x + ax * k, 8, cells[home].y - ay * k),
        new Vector3(cells[home].x + bx * k, 8, cells[home].y - by * k),
      ]);
      const mark = CreateLineSystem("queen-mark", { lines: markLines }, scene);
      mark.color = new Color3(1, 0.86, 0.42);
      mark.alpha = 0.95;
      mark.isPickable = false; mark.parent = fieldRoot;
      glow.referenceMeshToUseItsOwnMaterial(mark);
      host.setAttribute("data-queen-mark", String(EDGES.length));
    }

    // ---- event glints: a ring that grows and fades on the issue's cell ----
    interface Effect { index: number; tone: Tone; start: number; flip: boolean; flare?: string; signalColor?: string; sourceAt?: number; priority?: number }
    let flaredPick: number | null = null;
    const effects: Effect[] = [];
    const rings: LinesMesh[] = [];
    for (let k = 0; k < RING_POOL; k += 1) {
      const pts: Vector3[] = [];
      for (let a = 0; a <= 16; a += 1) pts.push(new Vector3(Math.cos((a / 16) * Math.PI * 2), 0, Math.sin((a / 16) * Math.PI * 2)));
      const m = CreateLineSystem(`fx-${k}`, { lines: [pts], updatable: false }, scene);
      m.isPickable = false; m.isVisible = false; m.parent = fieldRoot;
      rings.push(m);
    }
    let lastEvents: HudEvent[] | null = null;
    let lastSignalHealth = '';
    const ingestEvents = (stamp: number) => {
      const list = eventsRef.current;
      const health=signalHealthRef.current.activity;
      if (list === lastEvents && lastSignalHealth === health) return;
      lastEvents = list;
      lastSignalHealth = health;
      const seen = seenEventsRef.current;
      const primed = eventsPrimedRef.current;
      const wall = Date.now();
      if(displaysRef.current) {
        const delivery=hiveSignalDelivery(list,wall,health,signalCursorRef.current,eventIdentity);
        signalCursorRef.current=delivery.cursor;
        for(const event of delivery.events) {
          const index=event.issue!==null ? indexByNumber.get(event.issue) : undefined;
          if(index===undefined) continue;
          const current=effects.find((fx): fx is Effect & HiveEventRing=>fx.index===index && fx.signalColor!==undefined && fx.sourceAt!==undefined && fx.priority!==undefined && stamp-fx.start<3000);
          const next=hiveSignalRing(current ?? null,event,stamp);
          if(current) Object.assign(current,next);
          else effects.push({index,tone:eventTone(event.kind),flip:false,...next});
        }
        return;
      }
      const candidates = list;
      for (const event of candidates) {
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
      const p = planeAt(x, y);
      return p ? catalogRef.current?catalogCellAt(catalogRef.current,p.x,p.z):hexIndexAt(p.x, p.z, cells.length) : -1;
    };
    let hover = -1;
    // ---- the cells the swarm is working on (the user, 2026-09-06) ---------
    // A bee's work names a file path on the wire, and a path belongs to exactly
    // one module cell: the longest module path that prefixes it. So the field
    // can show WHICH cells are being worked without ever naming a bee, which
    // the server withholds by design. An event with no resolvable path marks
    // nothing rather than guessing a cell.
    const modulePaths: Array<[string, number]> = [];
    cards.forEach((c, i) => { if (c && i !== home) modulePaths.push([c.title, i]); });
    modulePaths.sort((a, b) => b[0].length - a[0].length);
    // The wire names a path from the repository root ("trios/agent-server/...")
    // while the module scan is rooted inside it ("agent-server/..."), so a plain
    // prefix match found only the root module and every bee landed on one cell.
    // Every suffix of the path is tried and the DEEPEST module wins; the root is
    // the last resort, so a path that belongs somewhere real never falls to it.
    const cellOfPath = (path: string): number => {
      const parts = path.split("/");
      for (let drop = 0; drop < parts.length; drop += 1) {
        const rest = parts.slice(drop).join("/");
        for (const [t, i] of modulePaths) if (t !== "." && (rest === t || rest.startsWith(t + "/"))) return i;
      }
      const root = modulePaths.find(([t]) => t === ".");
      return root ? root[1] : -1;
    };
    // Work is a STATE, not an age. Measured 2026-09-06: the wire delivers in
    // bursts - the median gap between rows is 1 s and the p90 is 38 s - but the
    // newest row was 18 minutes old while the swarm reported itself working. A
    // wall-clock window of any length therefore reads 0 for most of the day and
    // says nothing true. So an issue is being worked when its LAST event on the
    // wire is not terminal, and the ring's brightness carries how long ago that
    // was, which is the fact the window was trying and failing to express.
    const ROUND_MS = 5 * 60 * 1000;
    let workingSeen: readonly HudEvent[] | null = null;
    let workingBoardSeen: typeof displays = undefined;
    let workingHealthSeen = '';
    let workingCells: number[] = [];
    let workingAgeOf = new Map<number, number>();
    let workingRing: LinesMesh | null = null;
    const refreshWorking = (nowWallMs: number) => {
      const list = eventsRef.current;
      const issueRows = displaysRef.current;
      const boardHealth = signalHealthRef.current.board;
      if (issueRows ? issueRows === workingBoardSeen && boardHealth === workingHealthSeen : list === workingSeen) return;
      workingSeen = list;
      workingBoardSeen = issueRows; workingHealthSeen = boardHealth;
      // the last event of every issue, oldest first so the newest wins
      const last = new Map<number, { at: number; kind: string; title: string }>();
      for (const e of [...list].sort((a, b) => Date.parse(a.at) - Date.parse(b.at))) {
        if (e.issue === null) continue;
        const at = Date.parse(e.at);
        if (Number.isFinite(at)) last.set(e.issue, { at, kind: e.kind, title: e.title });
      }
      const ageOf = new Map<number, number>();
      if (issueRows) {
        for (const number of hiveRunningIssueNumbers(issueRows.filter((row): row is HiveDisplay=>row!==null),boardHealth==='live')) {
          const i=indexByNumber.get(number); if(i!==undefined) ageOf.set(i,0);
        }
      } else for (const [issueNumber, { at, kind, title }] of last) {
        if (kind === "finished" || kind === "error") continue;
        const i = displaysRef.current ? indexByNumber.get(issueNumber) ?? -1 : cellOfPath(title);
        if (i < 0) continue;
        const age = nowWallMs - at;
        const seen = ageOf.get(i);
        if (seen === undefined || age < seen) ageOf.set(i, age);
      }
      const next = [...ageOf.keys()].sort((a, b) => a - b);
      const newest = next.length === 0 ? null : Math.min(...ageOf.values());
      host.setAttribute("data-working", String(next.length));
      host.setAttribute("data-working-age", newest === null ? "-" : String(Math.round(newest / 1000)));
      host.setAttribute("data-working-quiet", String([...ageOf.values()].filter((a) => a > ROUND_MS).length));
      workingAgeOf = ageOf;
      if (next.join(",") === workingCells.join(",")) return;
      workingCells = next;
      if (workingRing) { workingRing.dispose(); workingRing = null; }
      if (workingCells.length > 0) {
        const lines = workingCells.map((i) => { const p = hexCornersAt(cells[i].x, cells[i].y, HEX_R * 0.86, 0); return [...p, p[0]].map((c) => new Vector3(c.x, 5, c.y)); });
        const colours = workingCells.map((i) => {
          // fresh work burns, work silent for more than a round fades: the ring
          // never claims a bee is busy when the wire has said nothing for an hour
          const q = Math.max(0, Math.min(1, 1 - (workingAgeOf.get(i) ?? 0) / (12 * ROUND_MS)));
          const c = issueRows ? new Color4(.39,.86,1,.9) : new Color4(0.25 + 0.3 * q, 0.45 + 0.55 * q, 0.4 + 0.38 * q, 0.35 + 0.6 * q);
          return Array.from({ length: 7 }, () => c);
        });
        workingRing = CreateLineSystem("working", { lines, colors: colours, useVertexAlpha: true }, scene);
        workingRing.isPickable = false; workingRing.parent = fieldRoot;
        glow.referenceMeshToUseItsOwnMaterial(workingRing);
      }
    };


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
    const onCellClick = (e: MouseEvent) => {
      if (travelled > 6) { travelled = 0; return; }
      const rect = canvas.getBoundingClientRect();
      const index = cellUnder(e.clientX - rect.left, e.clientY - rect.top);
      if (index < 0) { host.setAttribute("data-hit", "off"); return; }
      if(catalogRef.current){if(layersRef.current.foundation&&(catalogRef.current.cells[index]||displaysRef.current?.[index]))catalogController.current?.inspect(index);else if(index===home)catalogController.current?.overview();host.setAttribute('data-hit',displaysRef.current?.[index]?'display':'resource');return;}
      if (displaysRef.current?.[index]) { inspectDisplay(index); host.setAttribute('data-hit','display'); return; }
      // An empty issue cell cannot inherit a colocated legacy module/issue.
      if (displaysRef.current && index !== home) {
        host.setAttribute('data-hit','void'); onPickRef.current?.(null); return;
      }
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
    };
    canvas.addEventListener('click', onCellClick);
    const onCellLeave = () => { hover = -1; showHoverCard(-1); };
    canvas.addEventListener('pointerleave', onCellLeave);

    // Project a bounded number of visible issue displays into CSS pixels.
    // Text is browser-native, never a256px texture enlarged by the camera.
    let displayTick = -Infinity;
    let displayEventSource: readonly HudEvent[] | null = null;
    let eventIssueNumbers = new Set<number>();
    let catalogLinks:LinesMesh|null=null,lastCatalogPick:number|null|undefined=undefined;
    const projectDisplays = (nowMs: number) => {
      if (nowMs - displayTick < 100) return;
      displayTick = nowMs;
      const width = host.clientWidth, height = host.clientHeight;
      const viewport = camera.viewport.toGlobal(width,height);
      const matrix = scene.getTransformMatrix();
      const world = fieldRoot.computeWorldMatrix(true);
      const project = (x: number,z: number) => Vector3.Project(new Vector3(x,0,z),world,matrix,viewport);
      const a = project(0,0), b = project(S_CELL,0), cellWidth = Math.abs(b.x-a.x);
      if(catalogRef.current){
        const resourceRows:HiveDisplayProjection[]=[];
        catalogRef.current.cells.forEach((row,index)=>{const rowWidth=cellWidth*cellScale(index);if(!row||(row.kind!=='repo'&&rowWidth<95))return;const p=project(cells[index].x,cells[index].y);if(p.x<0||p.y<0||p.x>width||p.y>height)return;resourceRows.push({index,x:p.x,y:p.y,width:rowWidth,height:rowWidth*2/Math.sqrt(3)});});
        resourceRows.sort((a,b)=>Number(catalogRef.current?.cells[b.index]?.kind==='repo')-Number(catalogRef.current?.cells[a.index]?.kind==='repo')||Number(b.index===pickRef.current)-Number(a.index===pickRef.current));
        const regionRows:HiveDisplayProjection[]=[];
        for(const region of catalogRef.current.regions??[]){
          const p=project(region.x,region.y),radius=region.focusRadius*cellWidth/S_CELL;
          // A small repository heading remains legible at overview, outside its issue cells.
          if(cellWidth*region.scale>=95||p.x+radius<0||p.x-radius>width||p.y+radius<0||p.y-radius>height)continue;
          regionRows.push({index:region.portalIndex,x:p.x,y:p.y-radius,width:radius*2,height:0});
        }
        catalogProjectRef.current?.(resourceRows.slice(0,40),regionRows);
        if(lastCatalogPick!==pickRef.current){lastCatalogPick=pickRef.current;catalogLinks?.dispose();const selected=pickRef.current;
          const selection=catalogSpecSelection(catalogRef.current,selected);
          const pairs=selection.links.length?selection.links:selected===null?catalogRef.current.cells.flatMap((c,i)=>c?.kind==='repo'?[[0,i] as [number,number]]:[]):catalogRef.current.edges.filter(([from,to])=>from===selected||to===selected);
          const lines=pairs.map(([from,to])=>[new Vector3(cells[from].x,10,cells[from].y),new Vector3(cells[to].x,10,cells[to].y)]);
          for(const index of selection.indices){const cell=cells[index],radius=HEX_R*cellScale(index)*.94;lines.push(Array.from({length:7},(_,i)=>{const a=Math.PI/6+i*Math.PI/3;return new Vector3(cell.x+radius*Math.cos(a),12,cell.y+radius*Math.sin(a));}));}
          // Ownership routes stay visible in the same map, never imply verified spec coverage.
          if(!selection.links.length)for(const region of catalogRef.current.regions??[]){const portal=cells[region.portalIndex];lines.push([new Vector3(portal.x,10,portal.y),new Vector3(region.x,10,region.y)]);}
          catalogLinks=lines.length?CreateLineSystem('catalog-source-edges',{lines},scene):null;
          if(catalogLinks){catalogLinks.parent=layerNodes.foundation;catalogLinks.color=Color3.FromHexString(selected===null||selection.links.length?'#FFD45A':'#64DCFF');catalogLinks.alpha=selected===null ? .3 : .95;catalogLinks.isPickable=false;}
          host.setAttribute('data-catalog-spec-pair',selection.indices.join(','));
          host.setAttribute('data-catalog-edges',String(lines.length));
        }
      }
      const projected: HiveDisplayProjection[] = [];
      displaysRef.current?.forEach((row,index) => {
        const cell = cells[index]; if (!row || !cell) return;
        const rowWidth=cellWidth*cellScale(index);
        if(hiveDisplayLod(rowWidth)==='overview')return;
        const p = project(cell.x,cell.y), h = rowWidth * 2 / Math.sqrt(3);
        if (p.x + rowWidth/2 < 0 || p.x-rowWidth/2 > width || p.y+h/2 < 0 || p.y-h/2 > height) return;
        projected.push({index,x:p.x,y:p.y,width:rowWidth,height:h});
      });
      projected.sort((a,b) => Number(b.index===selectedDisplayRef.current)-Number(a.index===selectedDisplayRef.current) || Math.hypot(a.x-width/2,a.y-height/2)-Math.hypot(b.x-width/2,b.y-height/2));
      const visible = projected.slice(0,32);
      setProjections(previous => previous.length === visible.length && previous.every((p,i) => {
        const next = visible[i];
        return p.index === next.index && Math.abs(p.x-next.x)<.1 && Math.abs(p.y-next.y)<.1 && Math.abs(p.width-next.width)<.1;
      }) ? previous : visible);
      host.setAttribute('data-display-visible',String(visible.length));
      host.setAttribute('data-display-cell-width',cellWidth.toFixed(1));
      host.setAttribute('data-display-lod',hiveDisplayLod(cellWidth));
      if(displayEventSource !== eventsRef.current) {
        displayEventSource = eventsRef.current;
        eventIssueNumbers = new Set(eventsRef.current.flatMap(e=>e.issue !== null ? [e.issue] : []));
      }
      host.setAttribute('data-event-cards',String(visible.filter(p=>eventIssueNumbers.has(displaysRef.current?.[p.index]?.number ?? -1)).length));
    };

    // ---- frame loop ---------------------------------------------------------
    const t0 = performance.now();
    let frames = 0;
    let lastMs = t0;
    engine.runRenderLoop(() => {
      const nowMs = performance.now();
      const dt = Math.min(nowMs - lastMs, 32); lastMs = nowMs;
      // the wall hangs in the air; the drift is small enough not to move a
      // cell out from under the pointer while the player is reading it
      fieldRoot.position.y = motionPreference.matches || selectedDisplayRef.current !== null ? 0 : Math.sin(nowMs / 6400) * 7;
      host.setAttribute('data-reduced-motion',String(motionPreference.matches));
      // the working cells breathe so a still frame still says which are live
      refreshWorking(Date.now());
      if (workingRing) workingRing.alpha = motionPreference.matches ? .8 : .65 + .15 * Math.sin(nowMs / 1600);
      // the zoom glides instead of snapping, and it glides toward the cursor:
      // an orthographic frustum is a uniform scale about the target, so moving
      // the target by (1 - 1/f) toward the anchor keeps that point still
      if (zoom !== zoomGoal) {
        const prev = zoom;
        zoom = motionPreference.matches || Math.abs(zoomGoal - zoom) < 1e-4 ? zoomGoal : zoom + (zoomGoal - zoom) * (1 - Math.pow(2, -dt / 60));
        const f = zoom / prev;
        if (anchor && f !== 1) {
          const k = 1 - 1 / f;
          const worldAnchor = hiveWallToWorld(anchor.x, anchor.z);
          camera.target.x += (worldAnchor.x - camera.target.x) * k;
          camera.target.y += (worldAnchor.y + fieldRoot.position.y - camera.target.y) * k;
          clampTarget();
        }
        fit();
      }
      // The box can change while no frame runs (a hidden pane, fullscreen,
      // a pane resized before it is shown); a ResizeObserver alone missed
      // that and left the field clipped to the old canvas. Check every frame.
      const cw = canvas.clientWidth, ch = canvas.clientHeight;
      const dpr = Math.min(2,Math.max(1,window.devicePixelRatio || 1));
      if ((cw > 0 && ch > 0) && (Math.abs(canvas.width-cw*dpr)>1 || Math.abs(canvas.height-ch*dpr)>1)) { engine.setHardwareScalingLevel(1/dpr); engine.resize(); fit(); }
      if (insetRef.current !== appliedInset) fit();
      // the layers: applied on change, no rebuild; the host mirrors the applied state
      const want = layersRef.current;
      let changed = false;
      for (const k of FIELD_LAYERS) { if (layerNodes[k].isEnabled(false) !== want[k]) { layerNodes[k].setEnabled(want[k]); changed = true; } }
      if (changed || frames === 0) { host.setAttribute("data-layers", FIELD_LAYERS.filter((k) => want[k]).join(",") || "none"); const fc = host.getAttribute("data-foundation-cells"); if (fc !== null) host.setAttribute("data-foundation-shown", want.foundation ? fc : "0"); }
      aimBees();
      bees.forEach((b, k) => {
        const quiet = motionPreference.matches || (displaysRef.current && signalHealthRef.current.board !== 'live');
        if(quiet) b.t = 1;
        if (b.t < 1) b.t = Math.min(1, b.t + (b.speed * dt) / 1000);
        const A = cells[b.from], B = cells[b.to];
        if (!A || !B) return;
        const e = b.t < 0.5 ? 2 * b.t * b.t : 1 - 2 * (1 - b.t) * (1 - b.t);
        let x = A.x + (B.x - A.x) * e, z = A.y + (B.y - A.y) * e;
        if (b.t >= 1 && b.busy && !quiet) { const ph = nowMs / 700 + b.hover; x = B.x + Math.cos(ph) * S * 0.12; z = B.y + Math.sin(ph * 1.3) * S * 0.08; }
        b.mote.isVisible = !displaysRef.current || signalHealthRef.current.board === 'live' || !b.busy;
        b.mote.position.set(x, 4 + (b.busy && !quiet ? Math.abs(Math.sin(nowMs / 140 + k)) * 4 : 0), z);
        b.mote.scaling.setAll(b.busy ? 1 : 0.62);
        const line = flightLines[k];
        if (b.busy && b.t < 1) { CreateDashedLines(`flight-${b.slot}`, { points: [new Vector3(A.x, 2, A.y), new Vector3(B.x, 2, B.y)], dashSize: 6, gapSize: 4, dashNb: 40, instance: line }, scene); line.isVisible = true; }
        else line.isVisible = false;
      });
      ingestEvents(nowMs);
      let write = 0;
      for (let i = 0; i < effects.length; i += 1) {
        const fx = effects[i]; const cell = cells[fx.index]; const life = fx.signalColor ? 3000 : fx.flare ? 500 : fx.flip ? 900 : 1300; const age = nowMs - fx.start;
        if (!cell || age > life || (fx.signalColor && signalHealthRef.current.activity !== 'live')) continue;
        effects[write] = fx; write += 1;
      }
      effects.length = Math.min(write, RING_POOL);
      for (let k = 0; k < RING_POOL; k += 1) {
        const fx = effects[k]; const ring = rings[k];
        if (!fx) { ring.isVisible = false; continue; }
        const cell = cells[fx.index]; const life = fx.signalColor ? 3000 : fx.flare ? 500 : fx.flip ? 900 : 1300; const u2 = motionPreference.matches ? .45 : (nowMs - fx.start) / life;
        const r = fx.flare ? S * (0.9 - 0.6 * u2) : S * (0.12 + 0.5 * u2);
        ring.position.set(cell.x, 1.5, cell.y);
        ring.scaling.set(r, 1, r);
        ring.color = Color3.FromHexString(fx.signalColor ?? fx.flare ?? TONE_HEX[fx.tone]);
        ring.alpha = 0.9 * (1 - u2);
        ring.isVisible = true;
      }
      const p = selectedDisplayRef.current ?? pickRef.current;
      if (p !== null && cells[p]) placeRing(picked, p, 1.4); else picked.isVisible = false;
      if (p !== flaredPick) { flaredPick = p; if (!catalogRef.current && !displaysRef.current && p !== null && cells[p] && effects.length < RING_POOL) effects.push({ index: p, tone: "muted", start: nowMs, flip: false, flare: ringTone(cells[p].own as Territory) }); }
      // a hovered plinth (K-5) draws the link from the ring's stone to the module cells it owns; nothing is drawn for a ring that owns no placed module
      const linkRing = !displaysRef.current && hover >= 0 && layersRef.current.castle && castleLinks ? castleLinks.ringOfCell.get(hover) ?? null : null;
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
      // the cell under the pointer lights up, whatever it holds (the user,
      // 2026-09-06). It used to light only a module, the hub or a honey cell,
      // so most of the comb answered nothing and the board felt dead.
      if (hover >= 0 && hover !== p && cells[hover]) placeDashed(hover, 1.4); else hovered.isVisible = false;
      // the cell under the hand rises; the picked cell stays up
      const wantLift = p !== null && cells[p] ? p : hover >= 0 && cells[hover] ? hover : -1;
      if (wantLift !== liftIndex) { liftIndex = wantLift; if (liftIndex >= 0) {lift.position.set(cells[liftIndex].x, liftY, cells[liftIndex].y);lift.scaling.set(cellScale(liftIndex),1,cellScale(liftIndex));} }
      const goalY = liftIndex >= 0 ? 16 : 0;
      liftY = motionPreference.matches ? goalY : liftY + (goalY - liftY) * (1 - Math.pow(2, -dt / 55));
      if (liftIndex >= 0) { lift.isVisible = true; lift.position.set(cells[liftIndex].x, liftY, cells[liftIndex].y); }
      else if (liftY < 0.4) lift.isVisible = false; else lift.position.y = liftY;
      showHoverCard(!catalogRef.current && !displaysRef.current && layersRef.current.foundation && hover >= 0 ? hover : -1);
      scene.render();
      projectDisplays(nowMs);
      savedViewRef.current = {zoom,x:camera.target.x,y:camera.target.y,focusKey:focusIndex !== null ? displaysRef.current?.[focusIndex]?.key ?? catalogRef.current?.cells[focusIndex]?.key ?? null : null,connection:focusConnection};
      viewStore.set(sceneKey,savedViewRef.current);
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
      viewStore.set(sceneKey,{zoom,x:camera.target.x,y:camera.target.y,focusKey:focusIndex===null?null:viewKey(focusIndex),connection:focusConnection});
      clearHoverCard();
      canvas.removeEventListener('click',onCellClick);
      canvas.removeEventListener('pointerleave',onCellLeave);
      displayControllerRef.current = null;
      document.removeEventListener("visibilitychange", onVisible);
      document.removeEventListener("fullscreenchange", onVisible);
      canvas.removeEventListener("wheel", onWheel);
      canvas.removeEventListener("pointerdown", onDown);
      canvas.removeEventListener("pointermove", onMove);
      canvas.removeEventListener("pointerup", onUp);
      canvas.removeEventListener("pointercancel", onUp);
      ro.disconnect(); engine.stopRenderLoop(); scene.dispose(); engine.dispose();
    };
  }, [signature,sceneKey]);

  useEffect(()=>{
    if(!inspectIssueKey){appliedIssueFocus.current=null;return;}
    const token=`${sceneKey}:${inspectIssueKey}`;
    if(appliedIssueFocus.current===token)return;
    const index=displaysRef.current?.findIndex(row=>row?.key===inspectIssueKey)??-1;
    if(index>=0){appliedIssueFocus.current=token;displayControllerRef.current?.inspect(index);}
  },[inspectIssueKey,signature,sceneKey]);

  useEffect(()=>{
    if(!inspectCatalogKey){appliedCatalogFocus.current=null;return;}
    const token=`${sceneKey}:${inspectCatalogKey}`;
    if(appliedCatalogFocus.current===token)return;
    const index=catalogRef.current?.cells.findIndex(row=>row?.key===inspectCatalogKey)??-1;
    if(index>=0){appliedCatalogFocus.current=token;catalogController.current?.inspect(index,true);}
  },[inspectCatalogKey,signature,sceneKey]);

  return (
    <div className="queen27-comb is-embedded is-babylon">
      <div className="queen27-comb-field" ref={hostRef} data-engine="babylon" data-look="hive" data-grid="hex" data-board-health={signalHealth.board} data-activity-health={signalHealth.activity}>
        <canvas className="queen-hive-scene" ref={canvasRef} style={{ touchAction: "none", outline: "none" }} />
        <QueenStarfield lang={lang}/>
        <div className="queen27-hover-card" ref={cardRef} aria-hidden="true" />
        {displays && <QueenHiveDisplays rows={displays} projections={projections} selected={selectedDisplay} events={events} lang={lang} controls={!catalogLayer} showRepository={!!catalogLayer} onIssueOpen={onDisplaySelect} controller={{ inspect: index => displayControllerRef.current?.inspect(index), overview: () => displayControllerRef.current?.overview(), hover: index => displayControllerRef.current?.hover(index) }} />}
        {displays && !catalogLayer && <QueenHiveTaskLegend rows={displays} lang={lang} health={signalHealth}/>}
        {!displays && law && (
          <div className="queen27-hive-law">
            {t27Coverage === null && <span data-law="unknown"><i />{law.unknown}</span>}
            <span data-law="t27"><i />{law.t27}</span>
            <span data-law="manual"><i />{law.manual}</span>
            <span data-law="awaiting"><i />{law.awaiting}</span>
            <span data-law="bees"><i />{law.bees} {workers?.slots.filter((slot) => slot.state === "busy").length ?? 0}/{workers?.slots.length ?? 0}</span>
          </div>
        )}
      </div>
    </div>
  );
}
