// The bee's body: one spaceship from the Kenney Space Kit (CC0), read once and
// drawn as many times as there are bees.
//
// WHICH MODEL, AND FROM WHERE
//
// public/queen/models/craft_speederA.glb is "Models/GLTF format/craft_speederA.glb"
// from Kenney's Space Kit 2.0 (kenney.nl/assets/space-kit, CC0; the licence sits
// beside it). It is the kit the field was built from on 2026-09-04 (#912) before
// the 3D objects left it (#949, #960): the same archive, 6,677,531 bytes, now
// contributing one 20 KB file. The README in that directory says what is loaded.
//
// WHY NOT THE glTF LOADER
//
// Babylon's SceneLoader with @babylonjs/loaders reads any glTF, and costs a
// chunk of loader code plus the PBR material it instantiates for every part --
// measured at +130 KB brotli when the kit was on the field (#912). This file
// is one GLB we chose: 4 primitives, flat palette colours (baseColorFactor, no
// textures), TRS nodes. Reading exactly that is ~80 lines, adds nothing to the
// Telegram WebView's download, and runs under node, so the gate can open the
// vendored file and check what the scene will draw. A GLB that is not this
// subset (a texture, a sparse accessor, a non-triangle primitive) is refused
// with a reason rather than drawn wrong.
//
// ONE DRAW CALL
//
// Each part's colour is written into the vertices, so the parts merge into one
// mesh with one material, and every bee is a thin instance of it: N ships, one
// draw call. Per-bee tint (a lane's hue, a quiet bee's dimming) rides on the
// instance colour, which multiplies the vertex colour in the shader.

export interface ShipGeometry {
  positions: Float32Array;
  normals: Float32Array;
  /** RGBA per vertex, gamma space, from each part's baseColorFactor. */
  colors: Float32Array;
  indices: Uint32Array;
  /** Extent after centring: x across the wings, y up, z nose to tail. */
  size: { x: number; y: number; z: number };
  parts: number;
}

type Json = Record<string, unknown>;
const COMPONENTS: Record<string, number> = { SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4, MAT4: 16 };

function mat4(node: Json): number[] {
  if (Array.isArray(node.matrix)) return node.matrix as number[];
  const [tx, ty, tz] = (node.translation as number[] | undefined) ?? [0, 0, 0];
  const [x, y, z, w] = (node.rotation as number[] | undefined) ?? [0, 0, 0, 1];
  const [sx, sy, sz] = (node.scale as number[] | undefined) ?? [1, 1, 1];
  // column-major, as glTF stores it: T * R * S
  return [
    (1 - 2 * (y * y + z * z)) * sx, 2 * (x * y + z * w) * sx, 2 * (x * z - y * w) * sx, 0,
    2 * (x * y - z * w) * sy, (1 - 2 * (x * x + z * z)) * sy, 2 * (y * z + x * w) * sy, 0,
    2 * (x * z + y * w) * sz, 2 * (y * z - x * w) * sz, (1 - 2 * (x * x + y * y)) * sz, 0,
    tx, ty, tz, 1,
  ];
}

function multiply(a: number[], b: number[]): number[] {
  const out = new Array<number>(16).fill(0);
  for (let c = 0; c < 4; c += 1) for (let r = 0; r < 4; r += 1) for (let k = 0; k < 4; k += 1) out[c * 4 + r] += a[k * 4 + r] * b[c * 4 + k];
  return out;
}

/** Reads the GLB subset described above. Throws with the reason when the file is outside it. */
export function readShipGlb(buffer: ArrayBuffer): ShipGeometry {
  const view = new DataView(buffer);
  if (view.getUint32(0, true) !== 0x46546c67 || view.getUint32(4, true) !== 2) throw new Error("not a glTF 2 binary");
  const jsonLength = view.getUint32(12, true);
  if (view.getUint32(16, true) !== 0x4e4f534a) throw new Error("first chunk is not JSON");
  const gltf = JSON.parse(new TextDecoder().decode(new Uint8Array(buffer, 20, jsonLength))) as Json;
  const binAt = 20 + jsonLength;
  if (view.getUint32(binAt + 4, true) !== 0x004e4942) throw new Error("second chunk is not BIN");
  const bin = binAt + 8;
  const accessors = gltf.accessors as Json[];
  const views = gltf.bufferViews as Json[];
  const read = (index: number): { data: number[]; size: number } => {
    const accessor = accessors[index];
    if (accessor.sparse) throw new Error("sparse accessor");
    const size = COMPONENTS[accessor.type as string];
    const bufferView = views[accessor.bufferView as number];
    const type = accessor.componentType as number;
    const bytes = type === 5126 || type === 5125 ? 4 : type === 5123 ? 2 : type === 5121 ? 1 : 0;
    if (!size || !bytes) throw new Error(`accessor type ${accessor.type}/${type}`);
    const stride = (bufferView.byteStride as number | undefined) ?? size * bytes;
    const start = bin + ((bufferView.byteOffset as number | undefined) ?? 0) + ((accessor.byteOffset as number | undefined) ?? 0);
    const data: number[] = [];
    for (let i = 0; i < (accessor.count as number); i += 1) {
      for (let k = 0; k < size; k += 1) {
        const at = start + i * stride + k * bytes;
        data.push(type === 5126 ? view.getFloat32(at, true) : type === 5125 ? view.getUint32(at, true) : type === 5123 ? view.getUint16(at, true) : view.getUint8(at));
      }
    }
    return { data, size };
  };
  const positions: number[] = [], normals: number[] = [], colors: number[] = [], indices: number[] = [];
  let parts = 0;
  const nodes = (gltf.nodes as Json[]) ?? [];
  const visit = (index: number, parent: number[]) => {
    const node = nodes[index];
    const world = multiply(parent, mat4(node));
    if (typeof node.mesh === "number") {
      for (const primitive of ((gltf.meshes as Json[])[node.mesh].primitives as Json[])) {
        if ((primitive.mode ?? 4) !== 4) throw new Error("not triangles");
        const attributes = primitive.attributes as Record<string, number>;
        const material = typeof primitive.material === "number" ? (gltf.materials as Json[])[primitive.material] : null;
        const pbr = (material?.pbrMetallicRoughness ?? {}) as Json;
        if (pbr.baseColorTexture) throw new Error("textured material");
        const base = (pbr.baseColorFactor as number[] | undefined) ?? [1, 1, 1, 1];
        const p = read(attributes.POSITION).data, n = attributes.NORMAL === undefined ? null : read(attributes.NORMAL).data;
        const first = positions.length / 3, vertices = p.length / 3;
        for (let v = 0; v < vertices; v += 1) {
          const [x, y, z] = [p[v * 3], p[v * 3 + 1], p[v * 3 + 2]];
          // glTF is right-handed and Babylon left-handed: mirror z, as the loader's root does
          positions.push(world[0] * x + world[4] * y + world[8] * z + world[12], world[1] * x + world[5] * y + world[9] * z + world[13], -(world[2] * x + world[6] * y + world[10] * z + world[14]));
          if (n) {
            const [nx, ny, nz] = [n[v * 3], n[v * 3 + 1], n[v * 3 + 2]];
            const wx = world[0] * nx + world[4] * ny + world[8] * nz, wy = world[1] * nx + world[5] * ny + world[9] * nz, wz = -(world[2] * nx + world[6] * ny + world[10] * nz);
            const length = Math.hypot(wx, wy, wz) || 1;
            normals.push(wx / length, wy / length, wz / length);
          } else normals.push(0, 1, 0);
          // baseColorFactor is linear; a StandardMaterial reads vertex colour as gamma
          colors.push(base[0] ** (1 / 2.2), base[1] ** (1 / 2.2), base[2] ** (1 / 2.2), 1);
        }
        const tri = primitive.indices === undefined ? Array.from({ length: vertices }, (_, i) => i) : read(primitive.indices as number).data;
        // the mirror flips the winding; swap two corners to keep the faces outward
        for (let t = 0; t + 2 < tri.length; t += 3) indices.push(first + tri[t], first + tri[t + 2], first + tri[t + 1]);
        parts += 1;
      }
    }
    for (const child of (node.children as number[] | undefined) ?? []) visit(child, world);
  };
  const scene = ((gltf.scenes as Json[] | undefined)?.[(gltf.scene as number | undefined) ?? 0]?.nodes as number[] | undefined) ?? nodes.map((_, i) => i);
  const identity = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];
  for (const root of scene) visit(root, identity);
  if (parts === 0 || indices.length === 0) throw new Error("no triangles");
  // centre the body on its own middle, so a bee turns about itself
  const min = [Infinity, Infinity, Infinity], max = [-Infinity, -Infinity, -Infinity];
  for (let i = 0; i < positions.length; i += 1) { min[i % 3] = Math.min(min[i % 3], positions[i]); max[i % 3] = Math.max(max[i % 3], positions[i]); }
  const mid = [0, 1, 2].map((k) => (min[k] + max[k]) / 2);
  for (let i = 0; i < positions.length; i += 1) positions[i] -= mid[i % 3];
  return {
    positions: new Float32Array(positions),
    normals: new Float32Array(normals),
    colors: new Float32Array(colors),
    indices: new Uint32Array(indices),
    size: { x: max[0] - min[0], y: max[1] - min[1], z: max[2] - min[2] },
    parts,
  };
}

/** Where the page serves the ship, relative so it works under app.t27.ai/game/ as well as at the root. */
export const SHIP_URL = "./queen/models/craft_speederA.glb";

let pending: Promise<ShipGeometry | null> | null = null;

/**
 * The ship, fetched and read once per page. A scene rebuild reuses it; a
 * failure resolves to null (the bees stay as glowing motes) and is not retried
 * until the page is reloaded, so a missing file costs one request, not one per
 * rebuild.
 */
export function loadShipGeometry(url: string = SHIP_URL): Promise<ShipGeometry | null> {
  pending ??= fetch(url)
    .then((response) => (response.ok ? response.arrayBuffer() : Promise.reject(new Error(`HTTP ${response.status}`))))
    .then(readShipGlb)
    .catch(() => null);
  return pending;
}

/** Six hues for lanes, so the same lane reads as the same bee across polls; white when the lane is unknown. */
const LANE_TINTS: ReadonlyArray<readonly [number, number, number]> = [
  [1, 0.86, 0.42], [0.45, 0.88, 1], [0.72, 1, 0.55], [1, 0.6, 0.85], [0.78, 0.66, 1], [1, 0.72, 0.5],
];

/** The instance colour for a bee: its lane's tint mixed over white, darkened while it is quiet. */
export function shipTint(lane: number | null, quiet: boolean): [number, number, number, number] {
  const hue = lane === null ? [1, 1, 1] : LANE_TINTS[((lane % LANE_TINTS.length) + LANE_TINTS.length) % LANE_TINTS.length];
  const dim = quiet ? 0.42 : 1;
  return [(0.55 + 0.45 * hue[0]) * dim, (0.55 + 0.45 * hue[1]) * dim, (0.55 + 0.45 * hue[2]) * dim, 1];
}
