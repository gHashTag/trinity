// The ROADMAP comb in Babylon.js, drawn the way the Queen's field is (the user,
// 2026-09-27: "сделай также на поле как Babylon.js"). The same picture as the
// flat comb - an inverted pyramid of hex cells, apex down, the seed t27c at the
// point - but as the field draws a hive: a wall of hex prisms hanging in front
// of the player, tone-mapped and bloomed like QueenCombBabylon.
//
//   * A cell's HEIGHT is how far its file has come: a built cell is a full
//     honey prism, a cell in review stands half as tall, one a bee is building
//     is a lit scaffold, a held one a low red slab, a free target a thin plate
//     in its language's colour. Cells not filed yet are rims only.
//   * SHIPS hover in front of the wall over the cells the Queen's board says are
//     running, each with a beam into its cell. Nothing is drawn that the board
//     did not report: the scene gets exactly the cells the flat comb gets.
//   * THE QUEEN'S ROUND is a band of light climbing the wall from the apex, on
//     the board's own pulse (pulsePhase, the same function the flat comb uses).
//   * The pointer lifts the cell under it toward the hand, as on the field; a
//     click opens the cell's issue. Dragging tilts the wall a little; the wheel
//     is left to the page, which scrolls.
//
// Renders ON DEMAND like the research city: while nothing moves, one frame per
// change or camera move. With motion allowed and something to animate (ships,
// the round, a raid) it runs at 30 FPS, and only while the canvas is on screen.
// DPR capped at 1.5.
import { Engine } from '@babylonjs/core/Engines/engine'
import { Scene } from '@babylonjs/core/scene'
import { ArcRotateCamera } from '@babylonjs/core/Cameras/arcRotateCamera'
import { Vector3, Matrix, Quaternion } from '@babylonjs/core/Maths/math.vector'
import { Color3, Color4 } from '@babylonjs/core/Maths/math.color'
import { Mesh } from '@babylonjs/core/Meshes/mesh'
import { VertexData } from '@babylonjs/core/Meshes/mesh.vertexData'
import { VertexBuffer } from '@babylonjs/core/Buffers/buffer'
import { TransformNode } from '@babylonjs/core/Meshes/transformNode'
import { StandardMaterial } from '@babylonjs/core/Materials/standardMaterial'
import { DynamicTexture } from '@babylonjs/core/Materials/Textures/dynamicTexture'
import { ImageProcessingConfiguration } from '@babylonjs/core/Materials/imageProcessingConfiguration'
import { CreateCylinder } from '@babylonjs/core/Meshes/Builders/cylinderBuilder'
import { CreateSphere } from '@babylonjs/core/Meshes/Builders/sphereBuilder'
import { CreateBox } from '@babylonjs/core/Meshes/Builders/boxBuilder'
import { CreatePlane } from '@babylonjs/core/Meshes/Builders/planeBuilder'
import { CreateLineSystem } from '@babylonjs/core/Meshes/Builders/linesBuilder'
import { HemisphericLight } from '@babylonjs/core/Lights/hemisphericLight'
import { DirectionalLight } from '@babylonjs/core/Lights/directionalLight'
import { GlowLayer } from '@babylonjs/core/Layers/glowLayer'
import '@babylonjs/core/Layers/effectLayerSceneComponent'
import '@babylonjs/core/Meshes/thinInstanceMesh'
import { Ray } from '@babylonjs/core/Culling/ray'
import { PointerEventTypes } from '@babylonjs/core/Events/pointerEvents'
import type { LinesMesh } from '@babylonjs/core/Meshes/linesMesh'
import type { Material } from '@babylonjs/core/Materials/material'
import { pulsePhase } from '../lib/roadmapGame'

export type RoadmapCellKind = 'seed' | 'built' | 'cracked' | 'review' | 'building' | 'held' | 'target' | 'future'

export interface RoadmapSceneCell {
  /** Centre in the flat comb's coordinates (SVG units, y grows downward). */
  x: number
  y: number
  kind: RoadmapCellKind
  /** The issue the cell is; null for the seed and for cells not filed yet. */
  number: number | null
  /** The colour of the language the cell's file is written in. */
  langHex: string
  /** In today's raid sector. */
  raid: boolean
}

export interface RoadmapSceneInput {
  cells: RoadmapSceneCell[]
  /** The flat comb's hex radius and frame, so both drawings share one geometry. */
  s: number
  frame: { cx: number; top: number; apex: number; halfTop: number }
  pulse: { lastRoundAt: string | null; roundSeconds: number } | null
  motion: 'static' | 'interactive'
}

export interface RoadmapSceneEvents {
  /** The cell under the pointer changed; null when it left every cell. */
  onHover(index: number | null, x: number, y: number): void
  /** A click or tap on a cell, with the pointer type that made it. */
  onPick(index: number, pointerType: string, x: number, y: number): void
  /** The WebGL context is gone; the page falls back to the flat comb. */
  onLost(message: string): void
}

export interface RoadmapSceneHandle {
  update(input: RoadmapSceneInput): void
  dispose(): void
}

export const DPR_CAP = 1.5
export const SCENE_FPS = 30

const MARK = '#08fab5'
const GOLD = '#ffd35a'
const RAID = '#ffae3a'
const HELD = '#ff8080'
const CRACK_RIM = '#ff6b6b'

/** How far a cell stands out of the wall, by state: how far its file has come. */
const HEIGHT: Record<RoadmapCellKind, number> = {
  seed: 2.6,
  built: 1.7,
  cracked: 1.6,
  review: 1.0,
  building: 0.8,
  held: 0.35,
  target: 0.14,
  future: 0,
}
const RIM: Record<Exclude<RoadmapCellKind, 'target'>, [string, number]> = {
  seed: ['#eafff7', 1],
  built: [MARK, 0.95],
  cracked: [CRACK_RIM, 1],
  review: [GOLD, 0.95],
  building: [MARK, 1],
  held: [HELD, 0.9],
  future: [MARK, 0.14],
}
/** Cell radius in wall units: the flat comb's s - 1.5 over s. */
const R = 0.9
const LIFT = 0.5
const TILT = { alpha: -Math.PI / 2 + 0.3, beta: Math.PI / 2 - 0.2 }
const FOV = 0.72

function hexCorners(x: number, y: number, r: number, z: number): Vector3[] {
  const out: Vector3[] = []
  for (let k = 0; k <= 6; k += 1) {
    const a = (Math.PI / 180) * (90 - 60 * k)
    out.push(new Vector3(x + r * Math.cos(a), y + r * Math.sin(a), z))
  }
  return out
}

export function mountRoadmapScene(
  canvas: HTMLCanvasElement,
  initial: RoadmapSceneInput,
  events: RoadmapSceneEvents,
): RoadmapSceneHandle {
  // Throws where WebGL is unavailable; the caller draws the flat comb instead.
  const engine = new Engine(canvas, true, { preserveDrawingBuffer: false, stencil: false, doNotHandleTouchAction: true }, false)
  engine.setHardwareScalingLevel(1 / Math.min(DPR_CAP, window.devicePixelRatio || 1))
  const scene = new Scene(engine)
  scene.clearColor = new Color4(0, 0, 0, 0)
  scene.skipPointerMovePicking = true
  // The field's look: ACES tone mapping with a little contrast, and a bloom on
  // every emissive rim, ship and beam.
  const ipc = scene.imageProcessingConfiguration
  ipc.toneMappingEnabled = true
  ipc.toneMappingType = ImageProcessingConfiguration.TONEMAPPING_ACES
  ipc.contrast = 1.22
  ipc.exposure = 1.08
  const glow = new GlowLayer('rm-glow', scene, { blurKernelSize: 16 })
  glow.intensity = 0.55

  const camera = new ArcRotateCamera('rm-cam', TILT.alpha, TILT.beta, 30, new Vector3(0, 0, -0.5), scene)
  camera.fov = FOV
  camera.minZ = 0.1
  camera.maxZ = 500
  camera.panningSensibility = 0
  camera.lowerAlphaLimit = -Math.PI / 2 - 0.55
  camera.upperAlphaLimit = -Math.PI / 2 + 0.55
  camera.lowerBetaLimit = Math.PI / 2 - 0.45
  camera.upperBetaLimit = Math.PI / 2 + 0.3
  // The page scrolls under the wheel; the wall only tilts under a drag, and only
  // with a mouse or a pen: on a touch screen a drag must scroll the page.
  camera.inputs.removeByType('ArcRotateCameraMouseWheelInput')
  camera.inputs.removeByType('ArcRotateCameraKeyboardMoveInput')
  const finePointer = window.matchMedia('(pointer: fine)').matches
  if (finePointer) camera.attachControl(canvas, true)

  const sky = new HemisphericLight('rm-sky', new Vector3(0, 1, -0.6), scene)
  sky.intensity = 0.42
  sky.groundColor = Color3.FromHexString('#02140d')
  // From the upper left and in front: the faces take the light, the sides of
  // each prism a shade apart, which is what reads as depth.
  const key = new DirectionalLight('rm-key', new Vector3(0.7, -0.45, 0.55), scene)
  key.intensity = 1.15
  key.diffuse = Color3.FromHexString('#fff0bf')

  // ---- rendering on demand --------------------------------------------------
  let disposed = false
  let dirty = true
  let raf = 0
  let lastFrame = 0
  let onScreen = true
  let staticTimer = 0
  let animate: ((t: number) => void) | null = null
  // Something on the wall moves: a ship, the round, a raid rim or a scaffold.
  let motionful = false
  let lastInput: RoadmapSceneInput = initial
  const moving = () => lastInput.motion === 'interactive' && motionful
  const frame = (t: number) => {
    raf = 0
    if (disposed) return
    if (moving() && onScreen && !document.hidden) {
      if (t - lastFrame >= 1000 / SCENE_FPS - 1) {
        lastFrame = t
        animate?.(t)
        scene.render()
        dirty = false
      }
      raf = window.requestAnimationFrame(frame)
      return
    }
    if (dirty) {
      animate?.(t)
      scene.render()
      dirty = false
    }
  }
  const requestRender = () => {
    dirty = true
    if (!raf && !disposed) raf = window.requestAnimationFrame(frame)
  }
  camera.onViewMatrixChangedObservable.add(requestRender)
  const visibility = new IntersectionObserver((entries) => {
    onScreen = entries.some((e) => e.isIntersecting)
    if (onScreen) requestRender()
  })
  visibility.observe(canvas)
  const onVisibility = () => { if (!document.hidden) requestRender() }
  document.addEventListener('visibilitychange', onVisibility)
  engine.onContextLostObservable.add(() => events.onLost('WebGL context lost'))

  // ---- geometry shared by every build ---------------------------------------
  const prismBase = (name: string) => {
    const m = CreateCylinder(name, { tessellation: 6, diameter: 2 * R, height: 1 }, scene)
    // Axis toward the camera (-z): the cap is the cell's face.
    m.rotation.x = -Math.PI / 2
    m.bakeCurrentTransformIntoVertices()
    // Pointy-top, like the flat comb: taller than wide.
    const bb = m.getBoundingInfo().boundingBox
    if (bb.maximum.x - bb.minimum.x > bb.maximum.y - bb.minimum.y) {
      m.rotation.z = Math.PI / 6
      m.bakeCurrentTransformIntoVertices()
    }
    return m
  }

  let meshes: Array<Mesh | TransformNode> = []
  let materials: Material[] = []
  let textures: DynamicTexture[] = []
  const keep = <T extends Mesh | TransformNode>(m: T): T => { meshes.push(m); return m }
  const mat = <T extends Material>(m: T): T => { materials.push(m); return m }
  const clear = () => {
    // Each node is in the list, so none is disposed through its parent.
    for (const m of meshes) m.dispose(true, false)
    for (const m of materials) m.dispose()
    for (const t of textures) t.dispose()
    meshes = []
    materials = []
    textures = []
    animate = null
    motionful = false
  }
  const solid = (name: string, hex: string, emissive: number, alpha = 1) => {
    const m = mat(new StandardMaterial(name, scene))
    m.diffuseColor = Color3.FromHexString(hex)
    m.emissiveColor = Color3.FromHexString(hex).scale(emissive)
    m.specularColor = new Color3(0.45, 0.42, 0.3)
    m.specularPower = 40
    m.alpha = alpha
    return m
  }
  const light = (name: string, hex: string, alpha = 1) => {
    const m = mat(new StandardMaterial(name, scene))
    m.diffuseColor = Color3.Black()
    m.specularColor = Color3.Black()
    m.emissiveColor = Color3.FromHexString(hex)
    m.disableLighting = true
    m.alpha = alpha
    m.backFaceCulling = false
    return m
  }

  // ---- state the pointer and the animation read -----------------------------
  let world: Array<{ X: number; Y: number; h: number }> = []
  let slots: Array<{ mesh: Mesh; i: number } | null> = []
  let hoverRing: LinesMesh | null = null
  let lifted = -1
  let pulseBand: Mesh | null = null
  let toWorldY = (y: number) => y
  let frameGeom = { top: 0, apex: 0, halfTop: 0, s: 1 }

  const placeInstance = (index: number, up: number) => {
    const slot = slots[index]
    const w = world[index]
    if (!slot || !w) return
    const m = Matrix.Scaling(1, 1, Math.max(w.h, 0.02)).multiply(Matrix.Translation(w.X, w.Y, -Math.max(w.h, 0.02) / 2 - up))
    slot.mesh.thinInstanceSetMatrixAt(slot.i, m, true)
  }

  const placePulse = () => {
    if (!pulseBand) return
    const p = lastInput.pulse
    const phase = p ? pulsePhase(p.lastRoundAt, p.roundSeconds, Date.now()) : null
    if (phase === null) {
      pulseBand.isVisible = false
      return
    }
    pulseBand.isVisible = true
    const { top, apex, halfTop, s } = frameGeom
    const centre = apex - phase * (apex - top)
    const lo = Math.min(apex, centre + 1.2 * s)
    const hi = Math.max(top, centre - 1.2 * s)
    const half = (y: number) => (halfTop * (apex - y)) / (apex - top) / s
    const z = -2.8
    const positions = [
      -half(lo), toWorldY(lo), z,
      half(lo), toWorldY(lo), z,
      half(hi), toWorldY(hi), z,
      -half(hi), toWorldY(hi), z,
    ]
    pulseBand.updateVerticesData(VertexBuffer.PositionKind, positions)
    pulseBand.refreshBoundingInfo()
  }

  const fit = () => {
    const w = canvas.clientWidth
    const h = canvas.clientHeight
    if (!w || !h) return
    const { top, apex, halfTop, s } = frameGeom
    const halfH = (apex - top) / (2 * s) + 0.8
    const halfW = halfTop / s + 0.8
    const t = Math.tan(FOV / 2)
    let r = Math.max(halfH / t, halfW / (t * (w / h))) + 1.2
    // The wall is tilted, so the near corner grows: step back until every
    // corner of the frame, at the depth of the tallest cells too, is in view.
    const corners: Vector3[] = []
    for (const z of [0, -HEIGHT.seed]) {
      corners.push(new Vector3(-halfTop / s, toWorldY(top), z), new Vector3(halfTop / s, toWorldY(top), z), new Vector3(0, toWorldY(apex), z))
    }
    camera.upperRadiusLimit = null
    camera.lowerRadiusLimit = null
    for (let i = 0; i < 24; i += 1) {
      camera.radius = r
      const vp = camera.getViewMatrix(true).multiply(camera.getProjectionMatrix(true))
      const inside = corners.every((c) => {
        const q = Vector3.TransformCoordinates(c, vp)
        return Math.abs(q.x) <= 0.94 && Math.abs(q.y) <= 0.94
      })
      if (inside) break
      r *= 1.06
    }
    camera.radius = r
    camera.lowerRadiusLimit = r * 0.7
    camera.upperRadiusLimit = r * 1.15
  }

  const build = (input: RoadmapSceneInput) => {
    clear()
    const { cells, s, frame: f } = input
    frameGeom = { top: f.top, apex: f.apex, halfTop: f.halfTop, s }
    const mid = (f.top + f.apex) / 2
    toWorldY = (y: number) => (mid - y) / s
    world = cells.map((c) => ({ X: (c.x - f.cx) / s, Y: (mid - c.y) / s, h: HEIGHT[c.kind] }))
    slots = cells.map(() => null)

    // The frame of the mark and a faint plate behind the comb.
    const tl = new Vector3(-f.halfTop / s, toWorldY(f.top), 0.04)
    const tr = new Vector3(f.halfTop / s, toWorldY(f.top), 0.04)
    const ap = new Vector3(0, toWorldY(f.apex), 0.04)
    const frameLines = keep(CreateLineSystem('rm-frame', { lines: [[tl, tr, ap, tl]] }, scene))
    frameLines.color = Color3.FromHexString(MARK)
    frameLines.alpha = 0.4
    frameLines.isPickable = false
    glow.referenceMeshToUseItsOwnMaterial(frameLines)
    const plate = keep(new Mesh('rm-plate', scene))
    const pd = new VertexData()
    pd.positions = [tl.x, tl.y, 0.06, tr.x, tr.y, 0.06, ap.x, ap.y, 0.06]
    pd.indices = [0, 1, 2]
    pd.applyToMesh(plate)
    plate.material = light('rm-plate-mat', MARK, 0.045)
    plate.isPickable = false
    glow.addExcludedMesh(plate)

    // Prisms: one thin-instanced mesh per state (per language for the targets),
    // not a mesh per cell.
    const batches = new Map<string, { hex: string; kind: RoadmapCellKind; items: number[] }>()
    cells.forEach((c, i) => {
      if (c.kind === 'future' || c.kind === 'seed') return
      const k = c.kind === 'target' ? `target:${c.langHex}` : c.kind
      const b = batches.get(k) ?? { hex: c.langHex, kind: c.kind, items: [] }
      b.items.push(i)
      batches.set(k, b)
    })
    let buildingMat: StandardMaterial | null = null
    for (const [k, b] of batches) {
      const m = keep(prismBase(`rm-prism-${k}`))
      m.isPickable = false
      m.alwaysSelectAsActiveMesh = true
      let material: StandardMaterial
      switch (b.kind) {
        case 'built': material = solid('rm-built', '#e89b12', 0.12); break
        case 'cracked': material = solid('rm-cracked', '#8a6a3a', 0.08); break
        case 'review': material = solid('rm-review', GOLD, 0.22, 0.45); break
        case 'building': material = solid('rm-building', MARK, 0.45, 0.5); buildingMat = material; break
        case 'held': material = solid('rm-held', HELD, 0.22, 0.4); break
        default: material = solid(`rm-target-${b.hex}`, b.hex, 0.35, 0.34)
      }
      m.material = material
      // Broad fills must not bloom into their neighbours; the rims carry the glow.
      if (b.kind !== 'building') glow.addExcludedMesh(m)
      const matrices = new Float32Array(16 * b.items.length)
      b.items.forEach((cellIndex, j) => {
        const w = world[cellIndex]
        Matrix.Scaling(1, 1, w.h).multiply(Matrix.Translation(w.X, w.Y, -w.h / 2)).copyToArray(matrices, 16 * j)
        slots[cellIndex] = { mesh: m, i: j }
      })
      m.thinInstanceSetBuffer('matrix', matrices, 16, false)
    }

    // The seed: the one hand-written thing, the tallest cell, lit, named.
    const seedIndex = cells.findIndex((c) => c.kind === 'seed')
    if (seedIndex >= 0) {
      const w = world[seedIndex]
      const seed = keep(prismBase('rm-seed'))
      seed.scaling.z = w.h
      seed.position.set(w.X, w.Y, -w.h / 2)
      seed.material = solid('rm-seed-mat', MARK, 0.85)
      seed.isPickable = false
      const dt = new DynamicTexture('rm-seed-label', { width: 256, height: 128 }, scene, true)
      textures.push(dt)
      dt.hasAlpha = true
      const ctx = dt.getContext() as unknown as CanvasRenderingContext2D
      ctx.clearRect(0, 0, 256, 128)
      dt.drawText('t27c', null, 86, 'bold 72px system-ui, sans-serif', '#02140d', 'transparent', true, true)
      const label = keep(CreatePlane('rm-seed-text', { width: 1.3, height: 0.65 }, scene))
      label.position.set(w.X, w.Y, -w.h - 0.02)
      const lm = mat(new StandardMaterial('rm-seed-text-mat', scene))
      lm.diffuseTexture = dt
      lm.useAlphaFromDiffuseTexture = true
      lm.emissiveColor = Color3.White()
      lm.disableLighting = true
      label.material = lm
      label.isPickable = false
      glow.addExcludedMesh(label)
    }

    // Rims on each cell's face; today's raid targets get their own, pulsing.
    const lines: Vector3[][] = []
    const colours: Color4[][] = []
    const raidLines: Vector3[][] = []
    const crackLines: Vector3[][] = []
    cells.forEach((c, i) => {
      const w = world[i]
      const corners = hexCorners(w.X, w.Y, R, -w.h - 0.01)
      if (c.kind === 'target' && c.raid) {
        raidLines.push(corners)
        return
      }
      const [hex, alpha] = c.kind === 'target' ? [c.langHex, 0.95] : RIM[c.kind]
      const col = Color3.FromHexString(hex)
      lines.push(corners)
      colours.push(corners.map(() => new Color4(col.r, col.g, col.b, alpha)))
      if (c.kind === 'cracked') {
        const z = -w.h - 0.015
        const x0 = w.X - 0.55
        const y0 = w.Y + 0.35
        crackLines.push([
          new Vector3(x0, y0, z),
          new Vector3(x0 + 0.35, y0 - 0.3, z),
          new Vector3(x0 + 0.5, y0 - 0.05, z),
          new Vector3(x0 + 0.85, y0 - 0.6, z),
          new Vector3(x0 + 1.1, y0 - 0.4, z),
        ])
      }
    })
    if (lines.length) {
      const rims = keep(CreateLineSystem('rm-rims', { lines, colors: colours, useVertexAlpha: true }, scene))
      rims.isPickable = false
      glow.referenceMeshToUseItsOwnMaterial(rims)
    }
    let raidRims: LinesMesh | null = null
    if (raidLines.length) {
      raidRims = keep(CreateLineSystem('rm-raid', { lines: raidLines }, scene))
      raidRims.color = Color3.FromHexString(RAID)
      raidRims.isPickable = false
      glow.referenceMeshToUseItsOwnMaterial(raidRims)
    }
    if (crackLines.length) {
      const cracks = keep(CreateLineSystem('rm-cracks', { lines: crackLines }, scene))
      cracks.color = Color3.FromHexString('#2a0a0a')
      cracks.isPickable = false
      glow.addExcludedMesh(cracks)
    }
    hoverRing = keep(CreateLineSystem('rm-hover', { lines: [hexCorners(0, 0, R * 1.04, 0)] }, scene))
    hoverRing.color = Color3.FromHexString('#eafff7')
    hoverRing.isPickable = false
    hoverRing.isVisible = false
    glow.referenceMeshToUseItsOwnMaterial(hoverRing)
    lifted = -1

    // The Queen's round: a band of light across the wall, in front of it.
    pulseBand = keep(new Mesh('rm-pulse', scene))
    const bd = new VertexData()
    bd.positions = new Array(12).fill(0)
    bd.indices = [0, 1, 2, 0, 2, 3]
    bd.applyToMesh(pulseBand, true)
    pulseBand.material = light('rm-pulse-mat', MARK, 0.13)
    pulseBand.isPickable = false
    pulseBand.alwaysSelectAsActiveMesh = true
    glow.addExcludedMesh(pulseBand)

    // Ships: one per cell the board says a bee is building, with a beam into it.
    const hullMat = solid('rm-hull', '#dffcf3', 0.12)
    const cockpitMat = light('rm-cockpit', MARK)
    const flameMat = light('rm-flame', RAID)
    const beamMat = light('rm-beam', MARK, 0.22)
    const ships: Array<{ node: TransformNode; flame: Mesh; beam: Mesh; baseY: number; face: Vector3; seed: number }> = []
    cells.forEach((c, i) => {
      if (c.kind !== 'building') return
      const w = world[i]
      const n = ships.length
      const side = n % 2 === 0 ? -1 : 1
      const node = keep(new TransformNode(`rm-ship-${i}`, scene))
      node.position.set(w.X + side * 1.1, w.Y + 2.6, -4.2)
      node.rotation.z = side * 0.28
      node.scaling.setAll(1.5)
      const hull = keep(CreateCylinder(`rm-hull-${i}`, { tessellation: 3, diameterTop: 0, diameterBottom: 0.95, height: 1.35 }, scene))
      hull.rotation.z = Math.PI
      hull.scaling.z = 0.45
      hull.parent = node
      hull.material = hullMat
      const wings = keep(CreateBox(`rm-wings-${i}`, { width: 1.7, height: 0.1, depth: 0.42 }, scene))
      wings.position.y = 0.3
      wings.parent = node
      wings.material = hullMat
      const cockpit = keep(CreateSphere(`rm-cockpit-${i}`, { diameter: 0.34, segments: 8 }, scene))
      cockpit.position.set(0, 0.05, -0.2)
      cockpit.parent = node
      cockpit.material = cockpitMat
      const flame = keep(CreateCylinder(`rm-flame-${i}`, { tessellation: 8, diameterTop: 0, diameterBottom: 0.36, height: 0.6 }, scene))
      flame.position.y = 1.0
      flame.parent = node
      flame.material = flameMat
      const beam = keep(CreateCylinder(`rm-beam-${i}`, { tessellation: 20, diameterTop: 0.12, diameterBottom: 1.45, height: 1, cap: Mesh.NO_CAP }, scene))
      beam.material = beamMat
      beam.rotationQuaternion = new Quaternion()
      for (const m of [hull, wings, cockpit, flame, beam]) m.isPickable = false
      ships.push({ node, flame, beam, baseY: node.position.y, face: new Vector3(w.X, w.Y, -w.h), seed: n })
    })
    const up = Vector3.Up()
    const dir = new Vector3()
    const nose = new Vector3()
    const aimBeam = (ship: (typeof ships)[number]) => {
      // The nose of a ship tilted by rotation.z, in wall units.
      const tilt = ship.node.rotation.z
      nose.set(ship.node.position.x + Math.sin(tilt) * 1.02, ship.node.position.y - Math.cos(tilt) * 1.02, ship.node.position.z)
      nose.subtractToRef(ship.face, dir)
      const length = dir.length()
      dir.scaleInPlace(1 / length)
      Quaternion.FromUnitVectorsToRef(up, dir, ship.beam.rotationQuaternion!)
      ship.beam.scaling.y = length
      ship.beam.position.set((nose.x + ship.face.x) / 2, (nose.y + ship.face.y) / 2, (nose.z + ship.face.z) / 2)
    }
    ships.forEach(aimBeam)

    canvas.dataset.scene = 'babylon'
    canvas.dataset.cells = String(cells.filter((c) => c.number !== null).length)
    canvas.dataset.ships = String(ships.length)
    canvas.dataset.raid = String(raidLines.length)

    motionful = ships.length > 0 || raidLines.length > 0 || buildingMat !== null || input.pulse !== null
    animate = (t: number) => {
      placePulse()
      if (lastInput.motion !== 'interactive') return
      const sec = t / 1000
      for (const ship of ships) {
        ship.node.position.y = ship.baseY + Math.sin(sec * 2.4 + ship.seed) * 0.15
        ship.flame.scaling.y = 0.8 + 0.35 * Math.abs(Math.sin(sec * 17 + ship.seed))
        aimBeam(ship)
      }
      beamMat.alpha = 0.14 + 0.1 * (Math.sin(sec * 4.5) + 1) / 2
      if (buildingMat) buildingMat.emissiveColor = Color3.FromHexString(MARK).scale(0.3 + 0.35 * (Math.sin(sec * 3) + 1) / 2)
      if (raidRims) raidRims.alpha = 0.45 + 0.55 * (Math.sin(sec * 3.9) + 1) / 2
    }
    fit()
  }

  // ---- the pointer: lift, card, click ----------------------------------------
  const pickRay = new Ray(Vector3.Zero(), Vector3.Forward(), 1e6)
  const cellAt = (px: number, py: number): number => {
    scene.createPickingRayToRef(px, py, null, pickRay, camera)
    const dz = pickRay.direction.z
    if (Math.abs(dz) < 1e-6) return -1
    let best = -1
    let bestD = R * R
    // Solve against the plane of each candidate's own face, so a tall prism is
    // found where it is drawn, not where the wall is.
    lastInput.cells.forEach((c, i) => {
      if (c.number === null && c.kind !== 'seed') return
      const w = world[i]
      const t = (-w.h - pickRay.origin.z) / dz
      if (t < 0) return
      const dx = pickRay.origin.x + pickRay.direction.x * t - w.X
      const dy = pickRay.origin.y + pickRay.direction.y * t - w.Y
      const d = dx * dx + dy * dy
      if (d < bestD) {
        bestD = d
        best = i
      }
    })
    return best
  }
  const setLift = (index: number) => {
    if (index === lifted) return
    if (lifted >= 0) placeInstance(lifted, 0)
    lifted = index
    if (index >= 0) placeInstance(index, LIFT)
    if (hoverRing) {
      if (index >= 0) {
        const w = world[index]
        const up = slots[index] ? LIFT : 0
        hoverRing.position.set(w.X, w.Y, -w.h - up - 0.03)
        hoverRing.isVisible = true
      } else {
        hoverRing.isVisible = false
      }
    }
    requestRender()
  }
  let downAt: [number, number] | null = null
  let travelled = 0
  scene.onPointerObservable.add((info) => {
    const x = scene.pointerX
    const y = scene.pointerY
    if (info.type === PointerEventTypes.POINTERMOVE) {
      if (downAt) {
        travelled += Math.abs(x - downAt[0]) + Math.abs(y - downAt[1])
        downAt = [x, y]
      }
      const index = cellAt(x, y)
      canvas.style.cursor = index >= 0 ? 'pointer' : finePointer ? 'grab' : 'default'
      if (index !== lifted) {
        setLift(index)
        events.onHover(index >= 0 ? index : null, x, y)
      }
    } else if (info.type === PointerEventTypes.POINTERDOWN) {
      downAt = [x, y]
      travelled = 0
    } else if (info.type === PointerEventTypes.POINTERUP) {
      if (downAt && travelled <= 6) {
        const index = cellAt(x, y)
        if (index >= 0) {
          setLift(index)
          events.onPick(index, (info.event as PointerEvent).pointerType ?? 'mouse', x, y)
        }
      }
      downAt = null
    }
  })
  const onLeave = () => {
    setLift(-1)
    events.onHover(null, 0, 0)
  }
  canvas.addEventListener('pointerleave', onLeave)

  const ro = new ResizeObserver(() => {
    engine.resize()
    fit()
    requestRender()
  })
  ro.observe(canvas)

  const armStatic = () => {
    window.clearInterval(staticTimer)
    staticTimer = 0
    // Without motion the round still moves, once a second, as on the flat comb.
    if (lastInput.motion === 'static' && lastInput.pulse) staticTimer = window.setInterval(requestRender, 1000)
  }

  const update = (input: RoadmapSceneInput) => {
    if (disposed) return
    const rebuild =
      input.cells !== lastInput.cells ||
      input.s !== lastInput.s ||
      input.frame.top !== lastInput.frame.top ||
      input.frame.apex !== lastInput.frame.apex ||
      input.frame.halfTop !== lastInput.frame.halfTop ||
      (input.pulse === null) !== (lastInput.pulse === null)
    lastInput = input
    if (rebuild) build(input)
    camera.inertia = input.motion === 'interactive' ? 0.9 : 0
    armStatic()
    requestRender()
  }

  build(initial)
  camera.inertia = initial.motion === 'interactive' ? 0.9 : 0
  armStatic()
  scene.onAfterRenderObservable.addOnce(() => { canvas.dataset.ready = '1' })
  requestRender()

  return {
    update,
    dispose() {
      disposed = true
      window.clearInterval(staticTimer)
      if (raf) window.cancelAnimationFrame(raf)
      ro.disconnect()
      visibility.disconnect()
      document.removeEventListener('visibilitychange', onVisibility)
      canvas.removeEventListener('pointerleave', onLeave)
      clear()
      glow.dispose()
      scene.dispose()
      engine.dispose()
    },
  }
}
