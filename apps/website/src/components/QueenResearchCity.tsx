import { Line, OrbitControls } from "@react-three/drei";
import { Canvas, useFrame, useThree } from "@react-three/fiber";
import {
  useEffect,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
  type CSSProperties,
} from "react";
import {
  Object3D,
  type Group,
  type InstancedMesh,
} from "three";
import {
  buildConstructionPlan,
  type ConstructionPlan,
  type ConstructionStage,
} from "./queenConstructionModel";
import {
  buildResearchCityModel,
  motionModeFromPreference,
  type CityPosition,
  type CityResearchEdge,
  type CityResearchNode,
  type ResearchCityModel,
  type ResearchState,
} from "./queenResearchCityModel";

interface CityWorkers {
  capacity: number;
  active: number;
  slots: Array<{ slot: number; state: "busy" | "idle" }>;
}

interface ResearchCityLabels {
  aria: string;
  title: string;
  copy: string;
  districts: string;
  laboratories: string;
  selected: string;
  evidence: string;
  offline: string;
  workers: string;
  buildTitle: string;
  complete: string;
  assembling: string;
  blueprint: string;
  sealed: string;
  dependencies: string;
}

interface QueenResearchCityProps {
  researchNodes: CityResearchNode[];
  researchEdges: CityResearchEdge[];
  researchLayers: string[];
  workers: CityWorkers | null;
  error: string | null;
  labels: ResearchCityLabels;
}

const STATE_COLORS: Record<ResearchState, string> = {
  researched: "#00f5a0",
  researching: "#64dcff",
  available: "#ffd45a",
  locked: "#263a32",
};

const CONSTRUCTION_FPS = 12;

const CONSTRUCTION_COLORS: Record<ConstructionStage, string> = {
  complete: "#00f5a0",
  assembling: "#64dcff",
  blueprint: "#ffd45a",
  sealed: "#263a32",
};

// react-use-measure waits for the first ResizeObserver delivery before R3F
// creates a renderer. Background strategy tabs may throttle that delivery,
// leaving the canvas at the browser's 300x150 default until it becomes active.
// Deliver one measured frame immediately and keep the native observer for all
// subsequent responsive changes.
class ImmediateResizeObserver {
  private readonly callback: ResizeObserverCallback;
  private readonly observer: ResizeObserver;

  constructor(callback: ResizeObserverCallback) {
    this.callback = callback;
    this.observer = new ResizeObserver(callback);
  }

  observe(target: Element, options?: ResizeObserverOptions) {
    this.observer.observe(target, options);
    queueMicrotask(() => this.callback([], this as unknown as ResizeObserver));
  }

  unobserve(target: Element) {
    this.observer.unobserve(target);
  }

  disconnect() {
    this.observer.disconnect();
  }
}

function useReducedMotion() {
  const query = "(prefers-reduced-motion: reduce)";
  const [reduced, setReduced] = useState(() => window.matchMedia(query).matches);

  useEffect(() => {
    const media = window.matchMedia(query);
    const update = () => setReduced(media.matches);
    update();
    media.addEventListener("change", update);
    return () => media.removeEventListener("change", update);
  }, []);

  return reduced;
}

function ConstructionClock({ enabled }: { enabled: boolean }) {
  const invalidate = useThree((state) => state.invalidate);

  useEffect(() => {
    if (!enabled) return undefined;
    const timer = window.setInterval(invalidate, 1_000 / CONSTRUCTION_FPS);
    return () => window.clearInterval(timer);
  }, [enabled, invalidate]);

  return null;
}

function InstancedLaboratoryFoundations({ model }: { model: ResearchCityModel }) {
  const mesh = useRef<InstancedMesh>(null);
  const transform = useMemo(() => new Object3D(), []);

  useLayoutEffect(() => {
    if (!mesh.current) return;
    [...model.positions.values()].forEach((position, index) => {
      transform.position.set(position.x, 0.12, position.z);
      transform.rotation.set(0, 0, 0);
      transform.scale.set(1, 1, 1);
      transform.updateMatrix();
      mesh.current?.setMatrixAt(index, transform.matrix);
    });
    mesh.current.instanceMatrix.needsUpdate = true;
  }, [model.positions, transform]);

  return (
    <instancedMesh
      ref={mesh}
      args={[undefined, undefined, model.positions.size]}
      frustumCulled
    >
      <cylinderGeometry args={[0.7, 0.92, 0.24, 8]} />
      <meshStandardMaterial color="#6f5725" metalness={0.9} roughness={0.28} />
    </instancedMesh>
  );
}

function ResearchLaboratory({
  node,
  position,
  stage,
  motionMode,
  selected,
  onSelect,
}: {
  node: CityResearchNode;
  position: CityPosition;
  stage: ConstructionStage;
  motionMode: "static" | "interactive";
  selected: boolean;
  onSelect: (id: string) => void;
}) {
  const color = STATE_COLORS[node.state];
  const construction = useRef<Group>(null);

  useFrame((state) => {
    if (
      construction.current &&
      stage === "assembling" &&
      motionMode === "interactive"
    ) {
      construction.current.rotation.y = state.clock.elapsedTime * 0.55;
    }
  });

  return (
    <group
      position={[position.x, 0, position.z]}
      onClick={(event) => {
        event.stopPropagation();
        onSelect(node.id);
      }}
    >
      <mesh position={[0, position.height / 2 + 0.2, 0]}>
        <cylinderGeometry args={[0.13, 0.52, position.height, 6]} />
        <meshStandardMaterial
          color={stage === "blueprint" ? "#4b442c" : "#9a792d"}
          metalness={0.92}
          roughness={0.22}
          wireframe={stage === "blueprint" || stage === "sealed"}
          transparent={stage === "blueprint" || stage === "sealed"}
          opacity={stage === "sealed" ? 0.28 : stage === "blueprint" ? 0.62 : 1}
        />
      </mesh>
      <mesh position={[0, position.height + 0.38, 0]} scale={selected ? 0.52 : 0.4}>
        <octahedronGeometry args={[0.62, 0]} />
        <meshStandardMaterial
          color={color}
          emissive={color}
          emissiveIntensity={node.state === "locked" ? 0.08 : selected ? 1.6 : 0.72}
          metalness={0.35}
          roughness={0.18}
        />
      </mesh>
      <mesh position={[0, 0.24, 0]} rotation={[Math.PI / 2, 0, 0]}>
        <torusGeometry args={[selected ? 0.88 : 0.76, 0.035, 8, 32]} />
        <meshBasicMaterial color={color} transparent opacity={selected ? 1 : 0.5} />
      </mesh>
      {stage === "assembling" && (
        <group ref={construction} position={[0, position.height * 0.55, 0]}>
          {[0.52, 0.76, 1].map((scale, index) => (
            <mesh
              key={scale}
              position={[0, index * 0.48 - 0.42, 0]}
              rotation={[Math.PI / 2, index * 0.45, 0]}
            >
              <torusGeometry args={[scale, 0.026, 6, 24]} />
              <meshBasicMaterial color="#64dcff" transparent opacity={0.82} />
            </mesh>
          ))}
        </group>
      )}
    </group>
  );
}

function CommandSpire({ workers }: { workers: CityWorkers | null }) {
  const liveColor = workers?.active ? "#64dcff" : "#53635c";

  return (
    <group>
      <mesh position={[0, 0.18, 0]}>
        <cylinderGeometry args={[1.55, 2.2, 0.36, 12]} />
        <meshStandardMaterial color="#6f5725" metalness={0.95} roughness={0.22} />
      </mesh>
      <mesh position={[0, 2.4, 0]}>
        <cylinderGeometry args={[0.16, 1.05, 4.5, 6]} />
        <meshStandardMaterial color="#a98735" metalness={0.92} roughness={0.2} />
      </mesh>
      <mesh position={[0, 4.95, 0]} rotation={[0, Math.PI / 4, 0]}>
        <octahedronGeometry args={[0.82, 0]} />
        <meshStandardMaterial
          color={liveColor}
          emissive={liveColor}
          emissiveIntensity={workers?.active ? 1.45 : 0.18}
          metalness={0.35}
          roughness={0.14}
        />
      </mesh>
      {[1.7, 2.25].map((radius) => (
        <mesh key={radius} position={[0, 0.42, 0]} rotation={[Math.PI / 2, 0, 0]}>
          <torusGeometry args={[radius, 0.055, 10, 64]} />
          <meshBasicMaterial color="#ffd45a" transparent opacity={0.72} />
        </mesh>
      ))}
      {workers?.slots.map((slot, index) => {
        const angle = (index / Math.max(1, workers.capacity)) * Math.PI * 2;
        const color = slot.state === "busy" ? "#00f5a0" : "#34483f";
        return (
          <mesh
            key={slot.slot}
            position={[Math.cos(angle) * 2.7, 0.32, Math.sin(angle) * 2.7]}
            rotation={[0, -angle, Math.PI / 4]}
          >
            <boxGeometry args={[0.34, 0.34, 0.34]} />
            <meshStandardMaterial
              color={color}
              emissive={color}
              emissiveIntensity={slot.state === "busy" ? 1 : 0.08}
              metalness={0.7}
              roughness={0.2}
            />
          </mesh>
        );
      })}
    </group>
  );
}

function ResearchCityScene({
  researchNodes,
  model,
  constructionPlan,
  workers,
  selectedId,
  onSelect,
  motionMode,
}: {
  researchNodes: CityResearchNode[];
  model: ResearchCityModel;
  constructionPlan: ConstructionPlan;
  workers: CityWorkers | null;
  selectedId: string;
  onSelect: (id: string) => void;
  motionMode: "static" | "interactive";
}) {
  const constructionById = useMemo(
    () =>
      new Map(constructionPlan.structures.map((structure) => [structure.id, structure])),
    [constructionPlan.structures],
  );
  const routeState = useMemo(
    () =>
      new Map(
        constructionPlan.routes.map((route) => [
          `${route.from}-${route.to}`,
          route.state,
        ]),
      ),
    [constructionPlan.routes],
  );
  const constructionActive =
    motionMode === "interactive" && constructionPlan.summary.assembling > 0;

  return (
    <>
      <ConstructionClock enabled={constructionActive} />
      <color attach="background" args={["#010706"]} />
      <fog attach="fog" args={["#010706", 18, 42]} />
      <ambientLight intensity={0.7} />
      <directionalLight position={[8, 14, 6]} intensity={2.2} color="#fff0bf" />
      <pointLight position={[0, 7, 0]} intensity={55} distance={24} color="#64dcff" />

      <gridHelper args={[48, 48, "#174c3a", "#09251d"]} position={[0, -0.01, 0]} />
      {model.layers.map((layer, layerIndex) => (
        <mesh
          key={layer}
          position={[0, 0.02, 0]}
          rotation={[Math.PI / 2, 0, 0]}
        >
          <torusGeometry args={[3.4 + layerIndex * 2.15, 0.018, 6, 128]} />
          <meshBasicMaterial color="#3b9b78" transparent opacity={0.25} />
        </mesh>
      ))}

      {model.routes.map(({ edge, from, to }) => {
        const state = routeState.get(`${edge.from}-${edge.to}`) ?? "dormant";
        return (
          <Line
            key={`${edge.from}-${edge.to}`}
            points={[
              [from.x, 0.14, from.z],
              [to.x, 0.14, to.z],
            ]}
            color={
              state === "energized"
                ? "#00f5a0"
                : state === "assembling"
                  ? "#64dcff"
                  : "#263a32"
            }
            lineWidth={state === "dormant" ? 0.35 : 0.72}
            transparent
            opacity={state === "dormant" ? 0.15 : 0.42}
          />
        );
      })}

      <CommandSpire workers={workers} />
      <InstancedLaboratoryFoundations model={model} />
      {researchNodes.map((node) => {
        const position = model.positions.get(node.id);
        const structure = constructionById.get(node.id);
        if (!position || !structure) return null;
        return (
          <ResearchLaboratory
            key={node.id}
            node={node}
            position={position}
            stage={structure.stage}
            motionMode={motionMode}
            selected={node.id === selectedId}
            onSelect={onSelect}
          />
        );
      })}

      <OrbitControls
        makeDefault
        enableDamping={motionMode === "interactive"}
        enablePan={false}
        minDistance={10}
        maxDistance={34}
        minPolarAngle={0.4}
        maxPolarAngle={1.35}
        target={[0, 1.2, 0]}
      />
    </>
  );
}

export function QueenResearchCity({
  researchNodes,
  researchEdges,
  researchLayers,
  workers,
  error,
  labels,
}: QueenResearchCityProps) {
  const reducedMotion = useReducedMotion();
  const motionMode = motionModeFromPreference(reducedMotion);
  const cityModel = useMemo(
    () =>
      buildResearchCityModel(
        researchNodes,
        researchEdges,
        researchLayers,
        error,
      ),
    [error, researchEdges, researchLayers, researchNodes],
  );
  const constructionPlan = useMemo(
    () => buildConstructionPlan(researchNodes, researchEdges, error),
    [error, researchEdges, researchNodes],
  );
  const defaultNode =
    researchNodes.find((node) => node.state === "researching") ??
    researchNodes.find((node) => node.state === "available") ??
    researchNodes[0] ??
    null;
  const [selectedId, setSelectedId] = useState(defaultNode?.id ?? "");
  const selectedNode =
    researchNodes.find((node) => node.id === selectedId) ?? defaultNode;
  const selectedStructure = constructionPlan.structures.find(
    (structure) => structure.id === selectedNode?.id,
  );

  if (!cityModel.available || !constructionPlan.available) {
    return (
      <section className="queen27-city is-offline" aria-label={labels.aria}>
        <div>
          <small>{labels.title}</small>
          <strong>{labels.offline}</strong>
        </div>
      </section>
    );
  }

  return (
    <section
      className="queen27-city"
      aria-label={labels.aria}
      data-motion={motionMode}
    >
      <header className="queen27-city-head">
        <div>
          <small>{labels.title}</small>
          <strong>{labels.copy}</strong>
        </div>
        <dl>
          <div>
            <dt>{labels.districts}</dt>
            <dd>{cityModel.layers.length}</dd>
          </div>
          <div>
            <dt>{labels.laboratories}</dt>
            <dd>{researchNodes.length}</dd>
          </div>
          <div>
            <dt>{labels.workers}</dt>
            <dd>{workers ? `${workers.active}/${workers.capacity}` : "—"}</dd>
          </div>
        </dl>
      </header>

      <section
        className="queen27-city-build-queue"
        aria-label={labels.buildTitle}
      >
        <header>
          <div>
            <small>{labels.buildTitle}</small>
            <strong>
              {constructionPlan.summary.complete} {labels.complete} ·{" "}
              {constructionPlan.summary.assembling} {labels.assembling}
            </strong>
          </div>
          <dl>
            {(
              ["complete", "assembling", "blueprint", "sealed"] as const
            ).map((stage) => (
              <div className={`is-${stage}`} key={stage}>
                <dt>{labels[stage]}</dt>
                <dd>{constructionPlan.summary[stage]}</dd>
              </div>
            ))}
          </dl>
        </header>
        <ol>
          {constructionPlan.structures.map((structure) => (
            <li key={structure.id}>
              <button
                type="button"
                className={`is-${structure.stage}`}
                aria-pressed={selectedNode?.id === structure.id}
                onClick={() => setSelectedId(structure.id)}
              >
                <i
                  aria-hidden="true"
                  style={{
                    "--construction-color": CONSTRUCTION_COLORS[structure.stage],
                  } as CSSProperties}
                />
                <span>{structure.layer}</span>
                <strong>{structure.label}</strong>
                <small>
                  {labels[structure.stage]} · {labels.dependencies}{" "}
                  {structure.dependenciesReady}/{structure.dependenciesTotal}
                </small>
              </button>
            </li>
          ))}
        </ol>
      </section>

      <div className="queen27-city-stage">
        <div className="queen27-city-canvas" aria-hidden="true">
          <Canvas
            frameloop="demand"
            dpr={[1, 1.5]}
            resize={{
              polyfill: ImmediateResizeObserver as unknown as typeof ResizeObserver,
            }}
            camera={{ position: [0, 15, 22], fov: 42, near: 0.1, far: 80 }}
            gl={{ antialias: true, powerPreference: "high-performance" }}
          >
            <ResearchCityScene
              researchNodes={researchNodes}
              model={cityModel}
              constructionPlan={constructionPlan}
              workers={workers}
              selectedId={selectedNode?.id ?? ""}
              onSelect={setSelectedId}
              motionMode={motionMode}
            />
          </Canvas>
        </div>

        <aside className="queen27-city-console">
          <span>{labels.selected}</span>
          {selectedNode && (
            <div aria-live="polite">
              <b>{selectedNode.layer}</b>
              <strong>{selectedNode.label}</strong>
              <small className={`is-${selectedNode.state}`}>
                {selectedNode.state} · {selectedNode.maturity}
              </small>
              {selectedStructure && (
                <small className={`is-${selectedStructure.stage}`}>
                  {labels[selectedStructure.stage]} · {labels.dependencies}{" "}
                  {selectedStructure.dependenciesReady}/
                  {selectedStructure.dependenciesTotal}
                </small>
              )}
              <p>
                <span>{labels.evidence}</span>
                {selectedNode.evidence}
              </p>
            </div>
          )}
          <ol aria-label={labels.laboratories}>
            {researchNodes.map((node) => (
              <li key={node.id}>
                <button
                  type="button"
                  className={`is-${node.state}`}
                  aria-pressed={selectedNode?.id === node.id}
                  onClick={() => setSelectedId(node.id)}
                  title={node.evidence}
                >
                  <i aria-hidden="true" />
                  <span>{node.layer}</span>
                  <strong>{node.label}</strong>
                </button>
              </li>
            ))}
          </ol>
        </aside>
      </div>
    </section>
  );
}
