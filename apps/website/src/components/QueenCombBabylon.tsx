// SPIKE (loop cycle 011, not a product decision): the same 189-island field
// as QueenComb, drawn by Babylon.js instead of canvas2D, so the engine
// question the user re-opened on 2026-09-04 can be answered with numbers on
// this repo's own scene: brotli delta, frame p95/p99 at the gate sizes under
// swiftshader, first frame. Mounted only behind `?engine=babylon`; the
// default comb is untouched. Selective imports on purpose - the UMD bundle
// is 6.2x larger than what this file pulls in.
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
import { PointerEventTypes } from "@babylonjs/core/Events/pointerEvents";
import "@babylonjs/core/Culling/ray";
import { S, HH, summariseCells, queenIndexOf } from "./QueenComb";
import { crystalOf, type HudPick } from "./queenHud";

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
}

type Territory = "held" | "neutral" | "fog";
const TEX_ALPHA: Record<Territory, number> = { held: 0.85, neutral: 0.7, fog: 0.35 };
const DEPTH = 9;

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

export function QueenCombBabylon({ cards, workers, devices, onPick, pickIndex = null }: QueenCombBabylonProps) {
  const hostRef = useRef<HTMLDivElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const onPickRef = useRef(onPick);
  const pickRef = useRef<number | null>(pickIndex);
  useEffect(() => {
    onPickRef.current = onPick;
    pickRef.current = pickIndex;
  }, [onPick, pickIndex]);

  useEffect(() => {
    const canvas = canvasRef.current;
    const host = hostRef.current;
    if (!canvas || !host) return;
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
    const camera = new ArcRotateCamera("cam", Math.PI / 2, Math.PI / 2 - 0.62, 3000, centre, scene);
    camera.mode = Camera.ORTHOGRAPHIC_CAMERA;
    camera.lowerBetaLimit = 0.35;
    camera.upperBetaLimit = 1.35;
    camera.panningSensibility = 0;
    let zoom = 1;
    let manual = false;
    const fit = () => {
      const w = host.clientWidth || 1, h = host.clientHeight || 1;
      const fieldW = (maxX - minX) * 1.05, fieldH = (maxZ - minZ) * 1.05;
      const aspect = w / h;
      // width-limited or height-limited, whichever holds the whole field
      let halfW = fieldW / 2, halfH = halfW / aspect;
      if (halfH < fieldH / 2) { halfH = fieldH / 2; halfW = halfH * aspect; }
      halfW /= zoom; halfH /= zoom;
      camera.orthoLeft = -halfW; camera.orthoRight = halfW;
      camera.orthoTop = halfH; camera.orthoBottom = -halfH;
    };
    fit();
    camera.attachControl(canvas, true);
    canvas.addEventListener("wheel", (e) => { e.preventDefault(); manual = true; zoom = Math.min(8, Math.max(0.4, zoom * (e.deltaY < 0 ? 1.1 : 1 / 1.1))); fit(); }, { passive: false });
    camera.onViewMatrixChangedObservable.add(() => { if (camera.inertialAlphaOffset !== 0) manual = true; });

    // ---- ground: one mesh per territory (top) and one for sides + underside
    const texOf: Record<Territory, StandardMaterial> = {} as Record<Territory, StandardMaterial>;
    for (const own of ["held", "neutral", "fog"] as Territory[]) {
      const m = new StandardMaterial(`top-${own}`, scene);
      const t = new Texture(`./queen/ground-${own}-256.png`, scene, false, true);
      t.hasAlpha = true;
      m.diffuseTexture = t;
      m.emissiveColor = Color3.White();
      m.disableLighting = true;
      m.useAlphaFromDiffuseTexture = true;
      m.alpha = TEX_ALPHA[own];
      m.backFaceCulling = false;
      texOf[own] = m;
    }
    const sideMat = new StandardMaterial("side", scene);
    sideMat.emissiveColor = Color3.FromHexString("#06100c");
    sideMat.disableLighting = true;
    sideMat.backFaceCulling = false;

    const byTerritory: Record<Territory, number[]> = { held: [], neutral: [], fog: [] };
    cells.forEach((c, i) => byTerritory[c.own as Territory].push(i));
    const phase = (i: number) => i * 0.37;
    const bob = (i: number, t: number) => 6 + Math.sin(t * 0.6 + phase(i) * 1.7) * 4;

    interface Batch { mesh: Mesh; base: Float32Array; owners: number[] }
    const tops: Batch[] = [];
    const makeTop = (own: Territory, idx: number[]) => {
      const positions: number[] = [], indices: number[] = [], uvs: number[] = [], owners: number[] = [];
      idx.forEach((i) => {
        const c = cells[i];
        const v = positions.length / 3;
        const pts: [number, number][] = [[c.x - S / 2, c.yTop], [c.x + S / 2, c.yTop], [c.x, c.yTop + HH]];
        for (const [px, pz] of pts) {
          positions.push(px, 0, pz);
          uvs.push((px - (c.x - S / 2)) / S, 1 - (pz - c.yTop) / HH);
          owners.push(i);
        }
        indices.push(v, v + 2, v + 1);
      });
      const mesh = new Mesh(`top-${own}`, scene);
      const vd = new VertexData();
      vd.positions = positions; vd.indices = indices; vd.uvs = uvs;
      vd.applyToMesh(mesh, true);
      mesh.material = texOf[own];
      mesh.isPickable = true;
      tops.push({ mesh, base: Float32Array.from(positions), owners });
    };
    (Object.keys(byTerritory) as Territory[]).forEach((own) => { if (byTerritory[own].length) makeTop(own, byTerritory[own]); });

    // sides + underside in one mesh
    {
      const positions: number[] = [], indices: number[] = [], owners: number[] = [];
      cells.forEach((c, i) => {
        const pts: [number, number][] = [[c.x - S / 2, c.yTop], [c.x + S / 2, c.yTop], [c.x, c.yTop + HH]];
        const v = positions.length / 3;
        for (const [px, pz] of pts) { positions.push(px, 0, pz); owners.push(i); }
        for (const [px, pz] of pts) { positions.push(px, -DEPTH, pz); owners.push(i); }
        // underside
        indices.push(v + 3, v + 4, v + 5);
        // three side quads
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
      tops.push({ mesh, base: Float32Array.from(positions), owners });
    }

    // the mark's edges over the soil (the walls pass, reduced to the outline)
    const edgeLines = cells.map((c) => [
      new Vector3(c.x - S / 2, 0.5, c.yTop), new Vector3(c.x + S / 2, 0.5, c.yTop), new Vector3(c.x, 0.5, c.yTop + HH), new Vector3(c.x - S / 2, 0.5, c.yTop),
    ]);
    const edges = CreateLineSystem("edges", { lines: edgeLines, updatable: true }, scene);
    edges.color = new Color3(232 / 255, 232 / 255, 240 / 255);
    edges.alpha = 0.3;
    edges.isPickable = false;
    const edgeBase = Float32Array.from(edges.getVerticesData(VertexBuffer.PositionKind) ?? []);

    // picked outline
    const outline = CreateLineSystem("picked", { lines: [[new Vector3(0, 0, 0), new Vector3(0, 0, 0), new Vector3(0, 0, 0), new Vector3(0, 0, 0)]], updatable: true }, scene);
    outline.color = Color3.FromHexString("#00ff9c");
    outline.isPickable = false;

    // ---- sprites: one manager per texture, one draw call each ------------
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
    const running = cells.map((c, i) => ({ c, i })).filter(({ i }) => cards[i]?.column === "running").map(({ i }) => i);
    (workers?.slots ?? []).forEach((slot, k) => {
      if (slot.state === "busy" && running[k] !== undefined) put("wright", running[k], S * 0.5, S * 0.35, 16);
      else { const r = ring[(devices?.length ?? 0) + k]; if (r) put("larva", r.i, S * 0.35, 0, 16); }
    });

    // ---- picking ------------------------------------------------------------
    const pickAt = (x: number, y: number) => {
      const hit = scene.pick(x, y, (m) => m.isPickable);
      if (!hit?.hit || !hit.pickedPoint) return;
      const index = cellAtWorld(cells, hit.pickedPoint.x, hit.pickedPoint.z);
      if (index < 0) return;
      const card = cards[index];
      onPickRef.current?.({ index, isQueen: index === home, territory: cells[index].own, card: card ?? null, bee: null } as HudPick);
    };
    let downAt: [number, number] | null = null;
    scene.onPointerObservable.add((info) => {
      if (info.type === PointerEventTypes.POINTERDOWN) downAt = [scene.pointerX, scene.pointerY];
      if (info.type === PointerEventTypes.POINTERUP && downAt) {
        const dx = scene.pointerX - downAt[0], dy = scene.pointerY - downAt[1];
        if (dx * dx + dy * dy <= 36) pickAt(scene.pointerX, scene.pointerY);
        downAt = null;
      }
    });

    // ---- frame loop: the islands bob, sprites ride them, auto yaw ---------
    const t0 = performance.now();
    let frames = 0;
    engine.runRenderLoop(() => {
      const t = (performance.now() - t0) / 1000;
      if (!manual) camera.alpha = Math.PI / 2 + Math.sin(t / 9) * 0.35;
      for (const b of tops) {
        const pos = b.mesh.getVerticesData(VertexBuffer.PositionKind);
        if (!pos) continue;
        for (let v = 0; v < b.owners.length; v += 1) pos[v * 3 + 1] = b.base[v * 3 + 1] + bob(b.owners[v], t);
        b.mesh.updateVerticesData(VertexBuffer.PositionKind, pos);
      }
      const ep = edges.getVerticesData(VertexBuffer.PositionKind);
      if (ep) { for (let v = 0; v < ep.length / 3; v += 1) ep[v * 3 + 1] = edgeBase[v * 3 + 1] + bob(Math.floor(v / 4), t); edges.updateVerticesData(VertexBuffer.PositionKind, ep); }
      for (const s of standing) s.sprite.position.y = s.lift + bob(s.cell, t);
      const p = pickRef.current;
      if (p !== null && cells[p]) {
        const c = cells[p]; const y = bob(p, t) + 1;
        const op = outline.getVerticesData(VertexBuffer.PositionKind);
        if (op) { const pts = [[c.x - S / 2, c.yTop], [c.x + S / 2, c.yTop], [c.x, c.yTop + HH], [c.x - S / 2, c.yTop]]; pts.forEach(([px, pz], k) => { op[k * 3] = px; op[k * 3 + 1] = y; op[k * 3 + 2] = pz; }); outline.updateVerticesData(VertexBuffer.PositionKind, op); }
        outline.isVisible = true;
      } else outline.isVisible = false;
      scene.render();
      frames += 1;
      if (frames === 1) host.setAttribute("data-first-frame-ms", String(Math.round(performance.now() - t0)));
      host.setAttribute("data-frames", String(frames));
    });
    const ro = new ResizeObserver(() => { engine.resize(); fit(); });
    ro.observe(host);
    return () => { ro.disconnect(); engine.stopRenderLoop(); scene.dispose(); engine.dispose(); };
  }, [cards, workers, devices]);

  return (
    <div className="queen27-comb-field is-babylon" ref={hostRef} data-engine="babylon" style={{ position: "absolute", inset: 0 }}>
      <canvas ref={canvasRef} style={{ width: "100%", height: "100%", display: "block", touchAction: "none", outline: "none" }} />
    </div>
  );
}
