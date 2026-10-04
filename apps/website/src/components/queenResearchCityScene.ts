// The research city's 3D scene in Babylon.js (B-4: three.js leaves the Queen
// page; the comb has been Babylon since #908). The picture is the one the
// React Three Fiber scene drew: a gold command spire with a slot ring, the
// laboratories as tapered towers on instanced foundations with a lit crest
// by research state, the hardware foundry on the outer ring, routes as lines
// by construction state, layer rings on a grid. Renders ON DEMAND: one frame
// per change, camera move or construction tick (12 FPS while something is
// assembling and motion is allowed); nothing loops idle. DPR capped at 1.5.
import { Engine } from "@babylonjs/core/Engines/engine";
import { Scene } from "@babylonjs/core/scene";
import { ArcRotateCamera } from "@babylonjs/core/Cameras/arcRotateCamera";
import { Vector3, Matrix } from "@babylonjs/core/Maths/math.vector";
import { Color3, Color4 } from "@babylonjs/core/Maths/math.color";
import { Mesh } from "@babylonjs/core/Meshes/mesh";
import { StandardMaterial } from "@babylonjs/core/Materials/standardMaterial";
import { CreateCylinder } from "@babylonjs/core/Meshes/Builders/cylinderBuilder";
import { CreateBox } from "@babylonjs/core/Meshes/Builders/boxBuilder";
import { CreateTorus } from "@babylonjs/core/Meshes/Builders/torusBuilder";
import { CreatePolyhedron } from "@babylonjs/core/Meshes/Builders/polyhedronBuilder";
import { CreateLineSystem } from "@babylonjs/core/Meshes/Builders/linesBuilder";
import { HemisphericLight } from "@babylonjs/core/Lights/hemisphericLight";
import { DirectionalLight } from "@babylonjs/core/Lights/directionalLight";
import { PointLight } from "@babylonjs/core/Lights/pointLight";
import { PointerEventTypes } from "@babylonjs/core/Events/pointerEvents";
import "@babylonjs/core/Meshes/thinInstanceMesh";
import "@babylonjs/core/Culling/ray";
import type { CityResearchNode, ResearchCityModel, ResearchState } from "./queenResearchCityModel";
import type { ConstructionPlan, ConstructionStage } from "./queenConstructionModel";
import type { VerifiedHardwareRegistry } from "./queenHardwareRegistry";

export interface CityWorkersView {
  capacity: number;
  active: number;
  slots: Array<{ slot: number; state: "busy" | "idle" }>;
}

export interface ResearchCitySceneInput {
  researchNodes: CityResearchNode[];
  model: ResearchCityModel;
  constructionPlan: ConstructionPlan;
  hardware: VerifiedHardwareRegistry | null;
  workers: CityWorkersView | null;
  selectedId: string;
  motionMode: "static" | "interactive";
}

export interface ResearchCitySceneHandle {
  update(input: ResearchCitySceneInput): void;
  dispose(): void;
}

export const DPR_CAP = 1.5;
export const CONSTRUCTION_FPS = 12;

const STATE_COLORS: Record<ResearchState, string> = {
  researched: "#00f5a0",
  researching: "#64dcff",
  available: "#ffd45a",
  locked: "#263a32",
};
const HARDWARE_COLORS: Record<string, string> = {
  registered: "#47534e",
  synthesised: "#64dcff",
  programmed: "#ffd45a",
  online: "#00f5a0",
};
const ROUTE_COLORS: Record<string, [string, number]> = {
  energized: ["#00f5a0", 0.42],
  assembling: ["#64dcff", 0.42],
  dormant: ["#263a32", 0.15],
};

function metal(scene: Scene, name: string, hex: string, emissive = "#000000", emissiveIntensity = 0, alpha = 1, wireframe = false): StandardMaterial {
  const m = new StandardMaterial(name, scene);
  m.diffuseColor = Color3.FromHexString(hex);
  m.specularColor = new Color3(0.35, 0.33, 0.25);
  m.specularPower = 48;
  m.emissiveColor = Color3.FromHexString(emissive).scale(emissiveIntensity);
  m.alpha = alpha;
  m.wireframe = wireframe;
  return m;
}
function flat(scene: Scene, name: string, hex: string, alpha = 1): StandardMaterial {
  const m = new StandardMaterial(name, scene);
  m.emissiveColor = Color3.FromHexString(hex);
  m.disableLighting = true;
  m.alpha = alpha;
  return m;
}

export function mountResearchCity(canvas: HTMLCanvasElement, initial: ResearchCitySceneInput, onSelect: (id: string) => void): ResearchCitySceneHandle {
  const engine = new Engine(canvas, true, { preserveDrawingBuffer: false, stencil: false }, false);
  engine.setHardwareScalingLevel(1 / Math.min(DPR_CAP, window.devicePixelRatio || 1));
  const scene = new Scene(engine);
  scene.clearColor = new Color4(1 / 255, 7 / 255, 6 / 255, 1);
  scene.fogMode = Scene.FOGMODE_LINEAR;
  scene.fogColor = new Color3(1 / 255, 7 / 255, 6 / 255);
  scene.fogStart = 18;
  scene.fogEnd = 42;
  scene.skipPointerMovePicking = true;

  const camera = new ArcRotateCamera("city-cam", -Math.PI / 2, 0.98, 26, new Vector3(0, 1.2, 0), scene);
  camera.lowerRadiusLimit = 10;
  camera.upperRadiusLimit = 34;
  camera.lowerBetaLimit = 0.4;
  camera.upperBetaLimit = 1.35;
  camera.panningSensibility = 0;
  camera.minZ = 0.1;
  camera.maxZ = 80;
  camera.fov = (42 * Math.PI) / 180;
  camera.attachControl(canvas, true);

  const sky = new HemisphericLight("sky", new Vector3(0, 1, 0), scene);
  sky.intensity = 0.7;
  const sun = new DirectionalLight("sun", new Vector3(-8, -14, -6), scene);
  sun.intensity = 1.6;
  sun.diffuse = Color3.FromHexString("#fff0bf");
  const lamp = new PointLight("lamp", new Vector3(0, 7, 0), scene);
  lamp.intensity = 12;
  lamp.range = 24;
  lamp.diffuse = Color3.FromHexString("#64dcff");

  // ---- on-demand rendering ------------------------------------------------
  let dirty = true;
  let disposed = false;
  let raf = 0;
  const requestRender = () => {
    dirty = true;
    if (raf || disposed) return;
    raf = window.requestAnimationFrame(() => {
      raf = 0;
      if (disposed || !dirty) return;
      dirty = false;
      scene.render();
    });
  };
  camera.onViewMatrixChangedObservable.add(requestRender);
  const ro = new ResizeObserver(() => { engine.resize(); requestRender(); });
  ro.observe(canvas);

  // ---- the static furniture: grid and the spire's base -------------------
  const gridLines: Vector3[][] = [];
  for (let i = -24; i <= 24; i += 1) {
    gridLines.push([new Vector3(i, -0.01, -24), new Vector3(i, -0.01, 24)]);
    gridLines.push([new Vector3(-24, -0.01, i), new Vector3(24, -0.01, i)]);
  }
  const grid = CreateLineSystem("grid", { lines: gridLines }, scene);
  grid.color = Color3.FromHexString("#174c3a");
  grid.alpha = 0.5;
  grid.isPickable = false;

  // ---- everything that depends on the input is rebuilt on change ----------
  let built: Mesh[] = [];
  let constructionRings: Mesh[] = [];
  let selectionParts = new Map<string, { crest: Mesh; ring: Mesh; state: ResearchState }>();
  let constructionTimer = 0;
  let lastInput: ResearchCitySceneInput | null = null;
  let constructionAngle = 0;

  const clearBuilt = () => {
    for (const m of built) m.dispose(false, true);
    built = [];
    constructionRings = [];
    selectionParts = new Map();
  };
  const keep = <T extends Mesh>(m: T): T => { built.push(m); return m; };

  const applySelection = (selectedId: string) => {
    for (const [id, part] of selectionParts) {
      const selected = id === selectedId;
      const hex = STATE_COLORS[part.state];
      const mat = part.crest.material as StandardMaterial;
      mat.emissiveColor = Color3.FromHexString(hex).scale(part.state === "locked" ? 0.08 : selected ? 1.6 : 0.72);
      const s = selected ? 0.52 : 0.4;
      part.crest.scaling.set(s, s, s);
      (part.ring.material as StandardMaterial).alpha = selected ? 1 : 0.5;
      part.ring.scaling.set(selected ? 1.16 : 1, 1, selected ? 1.16 : 1);
    }
  };

  const build = (input: ResearchCitySceneInput) => {
    clearBuilt();
    const { model, constructionPlan, researchNodes, hardware, workers } = input;
    // layer rings
    model.layers.forEach((layer, layerIndex) => {
      const ring = keep(CreateTorus(`layer-${layer}`, { diameter: (3.4 + layerIndex * 2.15) * 2, thickness: 0.036, tessellation: 128 }, scene));
      ring.position.y = 0.02;
      ring.material = flat(scene, `layer-mat-${layer}`, "#3b9b78", 0.25);
      ring.isPickable = false;
    });
    // routes by construction state, one line system per state
    const routeState = new Map(constructionPlan.routes.map((r) => [`${r.from}-${r.to}`, r.state] as const));
    const byState: Record<string, Vector3[][]> = { energized: [], assembling: [], dormant: [] };
    for (const { edge, from, to } of model.routes) {
      const state = routeState.get(`${edge.from}-${edge.to}`) ?? "dormant";
      byState[state].push([new Vector3(from.x, 0.14, from.z), new Vector3(to.x, 0.14, to.z)]);
    }
    for (const [state, lines] of Object.entries(byState)) {
      if (!lines.length) continue;
      const ls = keep(CreateLineSystem(`routes-${state}`, { lines }, scene));
      const [hex, alpha] = ROUTE_COLORS[state];
      ls.color = Color3.FromHexString(hex);
      ls.alpha = alpha;
      ls.isPickable = false;
    }
    // the command spire
    const live = workers?.active ? "#64dcff" : "#53635c";
    const base = keep(CreateCylinder("spire-base", { diameterTop: 3.1, diameterBottom: 4.4, height: 0.36, tessellation: 12 }, scene));
    base.position.y = 0.18; base.material = metal(scene, "spire-base-mat", "#6f5725"); base.isPickable = false;
    const shaft = keep(CreateCylinder("spire-shaft", { diameterTop: 0.32, diameterBottom: 2.1, height: 4.5, tessellation: 6 }, scene));
    shaft.position.y = 2.4; shaft.material = metal(scene, "spire-shaft-mat", "#a98735"); shaft.isPickable = false;
    const crest = keep(CreatePolyhedron("spire-crest", { type: 1, size: 0.82 }, scene));
    crest.position.y = 4.95; crest.rotation.y = Math.PI / 4;
    crest.material = metal(scene, "spire-crest-mat", live, live, workers?.active ? 1.45 : 0.18); crest.isPickable = false;
    for (const r of [1.7, 2.25]) {
      const ring = keep(CreateTorus(`spire-ring-${r}`, { diameter: r * 2, thickness: 0.11, tessellation: 64 }, scene));
      ring.position.y = 0.42; ring.material = flat(scene, `spire-ring-mat-${r}`, "#ffd45a", 0.72); ring.isPickable = false;
    }
    (workers?.slots ?? []).forEach((slot, index) => {
      const angle = (index / Math.max(1, workers?.capacity ?? 1)) * Math.PI * 2;
      const hex = slot.state === "busy" ? "#00f5a0" : "#34483f";
      const cube = keep(CreateBox(`slot-${slot.slot}`, { size: 0.34 }, scene));
      cube.position.set(Math.cos(angle) * 2.7, 0.32, Math.sin(angle) * 2.7);
      cube.rotation.set(0, -angle, Math.PI / 4);
      cube.material = metal(scene, `slot-mat-${slot.slot}`, hex, hex, slot.state === "busy" ? 1 : 0.08); cube.isPickable = false;
    });
    // the hardware foundry on the outer ring
    (hardware?.devices ?? []).forEach((device, index) => {
      const n = Math.max(1, hardware?.devices.length ?? 1);
      const angle = (index / n) * Math.PI * 2;
      const radius = 14.7 + (index % 2) * 1.4;
      const hex = HARDWARE_COLORS[device.state] ?? "#47534e";
      const active = device.state === "online";
      const cx = Math.cos(angle) * radius, cz = Math.sin(angle) * radius;
      const pad = keep(CreateCylinder(`fpga-pad-${device.id}`, { diameterTop: 2.9, diameterBottom: 3.6, height: 0.36, tessellation: 8 }, scene));
      pad.position.set(cx, 0.18, cz); pad.material = metal(scene, `fpga-pad-mat-${device.id}`, "#6f5725"); pad.isPickable = false;
      const board = keep(CreateBox(`fpga-board-${device.id}`, { width: 1.65, height: 0.34, depth: 1.2 }, scene));
      board.position.set(cx, 0.52, cz); board.rotation.y = -angle + Math.PI / 2;
      board.material = metal(scene, `fpga-board-mat-${device.id}`, hex, hex, active ? 1.15 : device.state === "programmed" ? 0.5 : 0.2, 1, device.state === "synthesised"); board.isPickable = false;
      for (const x of [-0.58, 0.58]) for (const z of [-0.42, 0.42]) {
        const rx = cx + x * Math.cos(-angle + Math.PI / 2) - z * Math.sin(-angle + Math.PI / 2);
        const rz = cz + x * Math.sin(-angle + Math.PI / 2) + z * Math.cos(-angle + Math.PI / 2);
        const post = keep(CreateCylinder(`fpga-post-${device.id}-${x}-${z}`, { diameterTop: 0.16, diameterBottom: 0.36, height: 1.35, tessellation: 5 }, scene));
        post.position.set(rx, 1.2, rz); post.material = metal(scene, `fpga-post-mat-${device.id}-${x}-${z}`, "#9a792d"); post.isPickable = false;
        const gem = keep(CreatePolyhedron(`fpga-gem-${device.id}-${x}-${z}`, { type: 1, size: 0.18 }, scene));
        gem.position.set(rx, 2.02, rz); gem.material = metal(scene, `fpga-gem-mat-${device.id}-${x}-${z}`, hex, hex, active ? 1.4 : 0.42); gem.isPickable = false;
      }
      const ring = keep(CreateTorus(`fpga-ring-${device.id}`, { diameter: 4.1, thickness: 0.07, tessellation: 56 }, scene));
      ring.position.set(cx, 0.42, cz); ring.material = flat(scene, `fpga-ring-mat-${device.id}`, hex, active ? 0.88 : 0.42); ring.isPickable = false;
    });
    // laboratory foundations, thin-instanced
    const positions = [...model.positions.values()];
    if (positions.length) {
      const foundation = keep(CreateCylinder("foundation", { diameterTop: 1.4, diameterBottom: 1.84, height: 0.24, tessellation: 8 }, scene));
      foundation.material = metal(scene, "foundation-mat", "#6f5725");
      foundation.isPickable = false;
      const matrices: number[] = [];
      for (const p of positions) matrices.push(...Matrix.Translation(p.x, 0.12, p.z).toArray());
      foundation.thinInstanceSetBuffer("matrix", new Float32Array(matrices), 16, true);
    }
    // laboratories: a tapered tower by stage, a crest by state, a ring; construction rings while assembling
    const structureById = new Map(constructionPlan.structures.map((s) => [s.id, s.stage] as const));
    for (const node of researchNodes) {
      const position = model.positions.get(node.id);
      const stage: ConstructionStage | undefined = structureById.get(node.id);
      if (!position || !stage) continue;
      const hex = STATE_COLORS[node.state];
      const ghost = stage === "blueprint" || stage === "sealed";
      const body = keep(CreateCylinder(`lab-${node.id}`, { diameterTop: 0.26, diameterBottom: 1.04, height: position.height, tessellation: 6 }, scene));
      body.position.set(position.x, position.height / 2 + 0.2, position.z);
      body.material = metal(scene, `lab-mat-${node.id}`, stage === "blueprint" ? "#4b442c" : "#9a792d", "#000000", 0, stage === "sealed" ? 0.28 : stage === "blueprint" ? 0.62 : 1, ghost);
      body.metadata = { nodeId: node.id };
      body.isPickable = true;
      const crestMesh = keep(CreatePolyhedron(`lab-crest-${node.id}`, { type: 1, size: 0.62 }, scene));
      crestMesh.position.set(position.x, position.height + 0.38, position.z);
      crestMesh.material = metal(scene, `lab-crest-mat-${node.id}`, hex, hex, 0.72);
      crestMesh.metadata = { nodeId: node.id };
      crestMesh.isPickable = true;
      const ring = keep(CreateTorus(`lab-ring-${node.id}`, { diameter: 1.52, thickness: 0.07, tessellation: 32 }, scene));
      ring.position.set(position.x, 0.24, position.z);
      ring.material = flat(scene, `lab-ring-mat-${node.id}`, hex, 0.5);
      ring.isPickable = false;
      selectionParts.set(node.id, { crest: crestMesh, ring, state: node.state });
      if (stage === "assembling") {
        [0.52, 0.76, 1].forEach((scale, index) => {
          const r = keep(CreateTorus(`lab-build-${node.id}-${index}`, { diameter: scale * 2, thickness: 0.052, tessellation: 24 }, scene));
          r.position.set(position.x, position.height * 0.55 + index * 0.48 - 0.42, position.z);
          r.rotation.set(0, index * 0.45, 0);
          r.material = flat(scene, `lab-build-mat-${node.id}-${index}`, "#64dcff", 0.82);
          r.isPickable = false;
          constructionRings.push(r);
        });
      }
    }
    applySelection(input.selectedId);
  };

  // picking: a click on a laboratory selects its node
  let downAt: [number, number] | null = null;
  let travelled = 0;
  scene.onPointerObservable.add((info) => {
    if (info.type === PointerEventTypes.POINTERDOWN) { downAt = [scene.pointerX, scene.pointerY]; travelled = 0; }
    else if (info.type === PointerEventTypes.POINTERMOVE && downAt) { travelled += Math.abs(scene.pointerX - downAt[0]) + Math.abs(scene.pointerY - downAt[1]); downAt = [scene.pointerX, scene.pointerY]; }
    else if (info.type === PointerEventTypes.POINTERUP) {
      if (travelled <= 6) {
        const hit = scene.pick(scene.pointerX, scene.pointerY, (m) => m.isPickable);
        const id = (hit?.pickedMesh?.metadata as { nodeId?: string } | undefined)?.nodeId;
        if (id) onSelect(id);
      }
      downAt = null;
    }
  });

  const armConstruction = (input: ResearchCitySceneInput) => {
    window.clearInterval(constructionTimer);
    constructionTimer = 0;
    const active = input.motionMode === "interactive" && input.constructionPlan.summary.assembling > 0;
    if (!active) return;
    constructionTimer = window.setInterval(() => {
      constructionAngle += 0.55 / CONSTRUCTION_FPS;
      for (const r of constructionRings) r.rotation.y = constructionAngle;
      requestRender();
    }, 1000 / CONSTRUCTION_FPS);
  };

  const update = (input: ResearchCitySceneInput) => {
    if (disposed) return;
    const same = lastInput
      && lastInput.researchNodes === input.researchNodes
      && lastInput.model === input.model
      && lastInput.constructionPlan === input.constructionPlan
      && lastInput.hardware === input.hardware
      && lastInput.workers === input.workers;
    if (!same) build(input); else if (lastInput && lastInput.selectedId !== input.selectedId) applySelection(input.selectedId);
    if (!lastInput || lastInput.motionMode !== input.motionMode || !same) armConstruction(input);
    camera.inertia = input.motionMode === "interactive" ? 0.9 : 0;
    lastInput = input;
    requestRender();
  };

  update(initial);
  return {
    update,
    dispose() {
      disposed = true;
      window.clearInterval(constructionTimer);
      if (raf) window.cancelAnimationFrame(raf);
      ro.disconnect();
      clearBuilt();
      scene.dispose();
      engine.dispose();
    },
  };
}
