import { QueenResearchCity } from "./QueenResearchCity";
import type { VerifiedHardwareRegistry } from "./queenHardwareRegistry";

interface FactoryWorkers {
  capacity: number;
  active: number;
  idle: number;
  utilization: number;
  slots: Array<{ slot: number; state: "busy" | "idle" }>;
}

interface FactoryResearchNode {
  id: string;
  label: string;
  layer: string;
  maturity: "shipped" | "partial" | "blocked" | "planned" | "unknown";
  state: "researched" | "researching" | "available" | "locked";
  evidence: string;
}

interface FactoryLabels {
  aria: string;
  flow: string;
  throughput: string;
  queueDensity: string;
  workerBays: string;
  active: string;
  idle: string;
  station: string;
  modules: string;
  empty: string;
  offline: string;
  criteria: string;
  missing: string;
  openIssue: string;
  selectedModule: string;
  liveContract: string;
  cityTitle: string;
  cityCopy: string;
  cityDistricts: string;
  cityLaboratories: string;
  citySelected: string;
  cityEvidence: string;
  cityOffline: string;
  cityBuildTitle: string;
  cityComplete: string;
  cityAssembling: string;
  cityBlueprint: string;
  citySealed: string;
  cityDependencies: string;
  foundryTitle: string;
  foundryVerified: string;
  foundryUnavailable: string;
  foundryTotal: string;
  foundryOnline: string;
  foundryProgrammed: string;
  foundryKey: string;
}

interface QueenFactoryProps {
  workers: FactoryWorkers | null;
  researchNodes: FactoryResearchNode[];
  researchEdges: Array<{ from: string; to: string }>;
  researchLayers: string[];
  researchError: string | null;
  hardware: VerifiedHardwareRegistry | null;
  hardwareError: string | null;
  error: string | null;
  labels: FactoryLabels;
}

export function QueenFactory({
  workers,
  researchNodes,
  researchEdges,
  researchLayers,
  researchError,
  hardware,
  hardwareError,
  error,
  labels,
}: QueenFactoryProps) {
  const effectiveWorkers = researchError ? null : workers;

  return (
    <section
      className="queen27-factory"
      aria-label={labels.aria}
      data-worker-state={effectiveWorkers ? "live" : "offline"}
    >
      <header className="queen27-factory-command">
        <div>
          <small>{labels.flow}</small>
          <strong>{labels.liveContract}</strong>
        </div>
        <dl aria-label={labels.throughput}>
          <div>
            <dt>{labels.active}</dt>
            <dd>{effectiveWorkers?.active ?? "—"}</dd>
          </div>
          <div>
            <dt>{labels.idle}</dt>
            <dd>{effectiveWorkers?.idle ?? "—"}</dd>
          </div>
          <div>
            <dt>{labels.throughput}</dt>
            <dd>{effectiveWorkers ? `${effectiveWorkers.utilization}%` : "—"}</dd>
          </div>
        </dl>
      </header>

      <div className="queen27-factory-bays">
        <div>
          <span>{labels.workerBays}</span>
          <b>
            {effectiveWorkers
              ? `${effectiveWorkers.active}/${effectiveWorkers.capacity}`
              : labels.offline}
          </b>
        </div>
        <ol>
          {effectiveWorkers ? (
            effectiveWorkers.slots.map((slot) => (
              <li className={`is-${slot.state}`} key={slot.slot}>
                <i aria-hidden="true" />
                <span>Bee {String(slot.slot).padStart(2, "0")}</span>
                <b>{slot.state === "busy" ? labels.active : labels.idle}</b>
              </li>
            ))
          ) : (
            <li className="is-offline">
              <span title={researchError ?? error ?? undefined}>{labels.offline}</span>
            </li>
          )}
        </ol>
      </div>

      <QueenResearchCity
        researchNodes={researchNodes}
        researchEdges={researchEdges}
        researchLayers={researchLayers}
        workers={effectiveWorkers}
        error={researchError}
        hardware={hardware}
        hardwareError={hardwareError}
        labels={{
          aria: labels.cityTitle,
          title: labels.cityTitle,
          copy: labels.cityCopy,
          districts: labels.cityDistricts,
          laboratories: labels.cityLaboratories,
          selected: labels.citySelected,
          evidence: labels.cityEvidence,
          offline: labels.cityOffline,
          workers: labels.workerBays,
          buildTitle: labels.cityBuildTitle,
          complete: labels.cityComplete,
          assembling: labels.cityAssembling,
          blueprint: labels.cityBlueprint,
          sealed: labels.citySealed,
          dependencies: labels.cityDependencies,
          foundryTitle: labels.foundryTitle,
          foundryVerified: labels.foundryVerified,
          foundryUnavailable: labels.foundryUnavailable,
          foundryTotal: labels.foundryTotal,
          foundryOnline: labels.foundryOnline,
          foundryProgrammed: labels.foundryProgrammed,
          foundryKey: labels.foundryKey,
        }}
      />

      {/* The stations are gone. They were the board — backlog, blocked,
          running, in review, done, dropped — with the issue cards in them,
          which is the kanban's whole job and the mission map's other reading of
          it. Three views of one queue is two views too many, and this was the
          one where it said least: a factory floor drawn around someone else's
          columns. What is left here is the factory's own: the bee hangars, the
          construction partials, the laboratory and the foundry. */}
    </section>
  );
}
