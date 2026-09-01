import { Line, OrbitControls } from "@react-three/drei";
import { Canvas } from "@react-three/fiber";
import { useEffect, useMemo, useState } from "react";
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

function ResearchLaboratory({
  node,
  position,
  selected,
  onSelect,
}: {
  node: CityResearchNode;
  position: CityPosition;
  selected: boolean;
  onSelect: (id: string) => void;
}) {
  const color = STATE_COLORS[node.state];

  return (
    <group
      position={[position.x, 0, position.z]}
      onClick={(event) => {
        event.stopPropagation();
        onSelect(node.id);
      }}
    >
      <mesh position={[0, 0.12, 0]}>
        <cylinderGeometry args={[0.7, 0.92, 0.24, 8]} />
        <meshStandardMaterial color="#6f5725" metalness={0.9} roughness={0.28} />
      </mesh>
      <mesh position={[0, position.height / 2 + 0.2, 0]}>
        <cylinderGeometry args={[0.13, 0.52, position.height, 6]} />
        <meshStandardMaterial color="#9a792d" metalness={0.92} roughness={0.22} />
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
  workers,
  selectedId,
  onSelect,
  motionMode,
}: {
  researchNodes: CityResearchNode[];
  model: ResearchCityModel;
  workers: CityWorkers | null;
  selectedId: string;
  onSelect: (id: string) => void;
  motionMode: "static" | "interactive";
}) {
  return (
    <>
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

      {model.routes.map(({ edge, from, to }) => (
        <Line
          key={`${edge.from}-${edge.to}`}
          points={[
            [from.x, 0.14, from.z],
            [to.x, 0.14, to.z],
          ]}
          color="#45c9a0"
          lineWidth={0.6}
          transparent
          opacity={0.24}
        />
      ))}

      <CommandSpire workers={workers} />
      {researchNodes.map((node) => {
        const position = model.positions.get(node.id);
        if (!position) return null;
        return (
          <ResearchLaboratory
            key={node.id}
            node={node}
            position={position}
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
  const defaultNode =
    researchNodes.find((node) => node.state === "researching") ??
    researchNodes.find((node) => node.state === "available") ??
    researchNodes[0] ??
    null;
  const [selectedId, setSelectedId] = useState(defaultNode?.id ?? "");
  const selectedNode =
    researchNodes.find((node) => node.id === selectedId) ?? defaultNode;

  if (!cityModel.available) {
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
