import { useEffect, useMemo, useRef, useState, type CSSProperties } from "react";
import {
  buildConstructionPlan,
  type ConstructionStage,
} from "./queenConstructionModel";
import type { VerifiedHardwareRegistry } from "./queenHardwareRegistry";
import {
  buildResearchCityModel,
  motionModeFromPreference,
  type CityResearchEdge,
  type CityResearchNode,
} from "./queenResearchCityModel";
import { mountResearchCity, type ResearchCitySceneHandle, type ResearchCitySceneInput } from "./queenResearchCityScene";

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
  foundryTitle: string;
  foundryVerified: string;
  foundryUnavailable: string;
  foundryTotal: string;
  foundryOnline: string;
  foundryProgrammed: string;
  foundryKey: string;
}

interface QueenResearchCityProps {
  researchNodes: CityResearchNode[];
  researchEdges: CityResearchEdge[];
  researchLayers: string[];
  workers: CityWorkers | null;
  error: string | null;
  hardware: VerifiedHardwareRegistry | null;
  hardwareError: string | null;
  labels: ResearchCityLabels;
}



const CONSTRUCTION_COLORS: Record<ConstructionStage, string> = {
  complete: "#00f5a0",
  assembling: "#64dcff",
  blueprint: "#ffd45a",
  sealed: "#263a32",
};


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

export function QueenResearchCity({
  researchNodes,
  researchEdges,
  researchLayers,
  workers,
  error,
  hardware,
  hardwareError,
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

  // The 3D city is a Babylon scene (B-4) behind a plain canvas: mounted once,
  // updated on every change of its inputs, rendering on demand. The DOM
  // around it (queue, foundry, console, laboratories) is React as before.
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const sceneRef = useRef<ResearchCitySceneHandle | null>(null);
  const available = cityModel.available && constructionPlan.available;
  const sceneInput = useMemo<ResearchCitySceneInput>(
    () => ({
      researchNodes,
      model: cityModel,
      constructionPlan,
      hardware,
      workers,
      selectedId: selectedNode?.id ?? "",
      motionMode,
    }),
    [researchNodes, cityModel, constructionPlan, hardware, workers, selectedNode, motionMode],
  );
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas || !available) return;
    const handle = mountResearchCity(canvas, sceneInput, setSelectedId);
    sceneRef.current = handle;
    return () => {
      handle.dispose();
      sceneRef.current = null;
    };
    // mounted once per canvas; updates flow through the effect below
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [available]);
  useEffect(() => {
    sceneRef.current?.update(sceneInput);
  }, [sceneInput]);

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

      <section
        className={`queen27-hardware-foundry${hardware ? " is-verified" : " is-unavailable"}`}
        aria-label={labels.foundryTitle}
        data-hardware-verified={hardware ? "true" : "false"}
        data-hardware-error={hardwareError ? "true" : "false"}
      >
        <header>
          <div>
            <small>{labels.foundryTitle}</small>
            <strong>
              {hardware ? labels.foundryVerified : labels.foundryUnavailable}
            </strong>
          </div>
          <dl>
            <div>
              <dt>{labels.foundryTotal}</dt>
              <dd>{hardware?.summary.total ?? 0}</dd>
            </div>
            <div>
              <dt>{labels.foundryProgrammed}</dt>
              <dd>{hardware?.summary.programmed ?? 0}</dd>
            </div>
            <div>
              <dt>{labels.foundryOnline}</dt>
              <dd>{hardware?.summary.online ?? 0}</dd>
            </div>
            <div>
              <dt>{labels.foundryKey}</dt>
              <dd>{hardware?.keyId ?? "—"}</dd>
            </div>
          </dl>
        </header>
        {hardware ? (
          <ol>
            {hardware.devices.map((device) => (
              <li className={`is-${device.state}`} key={device.id}>
                <i aria-hidden="true" />
                <span>{device.state}</span>
                <strong>{device.family}</strong>
                <a href={device.evidence} target="_blank" rel="noreferrer">
                  {labels.evidence}
                </a>
              </li>
            ))}
          </ol>
        ) : (
          <p>{labels.foundryUnavailable}</p>
        )}
      </section>

      <div className="queen27-city-stage">
        <div className="queen27-city-canvas" aria-hidden="true">
          <canvas ref={canvasRef} />
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
