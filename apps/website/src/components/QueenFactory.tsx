import { useMemo, useState, type CSSProperties } from "react";
import { QueenResearchCity } from "./QueenResearchCity";
import type { VerifiedHardwareRegistry } from "./queenHardwareRegistry";

interface FactoryColumn {
  key: string;
  title: string;
  blurb: string;
}

interface FactoryCard {
  number: number;
  title: string;
  column: string;
  criteria?: number;
  needs?: string[];
}

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
  columns: FactoryColumn[];
  cards: FactoryCard[];
  repo: string | null;
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

const STATION_GLYPHS: Record<string, string> = {
  backlog: "◇",
  blocked: "⊘",
  running: "✦",
  review: "⬡",
  done: "◆",
  dropped: "×",
};

function stationLoad(cards: FactoryCard[], key: string) {
  return cards.filter((card) => card.column === key).length;
}

export function QueenFactory({
  columns,
  cards,
  repo,
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
  const [selectedNumber, setSelectedNumber] = useState<number | null>(null);
  const selected = useMemo(
    () => cards.find((card) => card.number === selectedNumber) ?? null,
    [cards, selectedNumber],
  );
  const peakLoad = useMemo(
    () => Math.max(0, ...columns.map((column) => stationLoad(cards, column.key))),
    [cards, columns],
  );

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
              <span>{researchError ?? error ?? labels.offline}</span>
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

      <div className="queen27-factory-viewport" tabIndex={0}>
        <div
          className="queen27-factory-floor"
          style={{ "--station-count": columns.length } as CSSProperties}
        >
          <div className="queen27-factory-grid" aria-hidden="true" />
          <div className="queen27-factory-bus" aria-hidden="true">
            <i />
            <i />
            <i />
          </div>

          {columns.map((column, stationIndex) => {
            const stationCards = cards.filter(
              (card) => card.column === column.key,
            );
            const isPeak = peakLoad > 0 && stationCards.length === peakLoad;
            return (
              <article
                className={`queen27-factory-station is-${column.key}${isPeak ? " is-peak" : ""}`}
                data-station={column.key}
                key={column.key}
              >
                <header>
                  <span>
                    {labels.station} {String(stationIndex + 1).padStart(2, "0")}
                  </span>
                  <b>{STATION_GLYPHS[column.key] ?? "◇"}</b>
                  <h3>{column.title}</h3>
                  <strong>{stationCards.length}</strong>
                </header>

                <div className="queen27-factory-machine" aria-hidden="true">
                  <span />
                  <i />
                  <b>{stationCards.length}</b>
                </div>

                <div className="queen27-factory-modules">
                  <small>
                    {stationCards.length} {labels.modules}
                    {isPeak ? ` · ${labels.queueDensity}` : ""}
                  </small>
                  {stationCards.map((card) => {
                    const issueHref = repo
                      ? `https://github.com/${repo}/issues/${card.number}`
                      : undefined;
                    return (
                      <a
                        href={issueHref}
                        target={issueHref ? "_blank" : undefined}
                        rel={issueHref ? "noreferrer" : undefined}
                        aria-disabled={!issueHref}
                        aria-current={
                          selectedNumber === card.number ? "true" : undefined
                        }
                        onFocus={() => setSelectedNumber(card.number)}
                        onMouseEnter={() => setSelectedNumber(card.number)}
                        key={card.number}
                      >
                        <i aria-hidden="true" />
                        <span>#{card.number}</span>
                        <strong>{card.title}</strong>
                        {typeof card.criteria === "number" && (
                          <small>
                            {card.criteria} {labels.criteria}
                          </small>
                        )}
                      </a>
                    );
                  })}
                  {stationCards.length === 0 && (
                    <em>{error ?? labels.empty}</em>
                  )}
                </div>
              </article>
            );
          })}
        </div>
      </div>

      <footer className="queen27-factory-inspector" aria-live="polite">
        <span>{labels.selectedModule}</span>
        {selected ? (
          <div>
            <b>#{selected.number}</b>
            <strong>{selected.title}</strong>
            <small>
              {selected.column}
              {typeof selected.criteria === "number"
                ? ` · ${selected.criteria} ${labels.criteria}`
                : ""}
              {selected.needs?.length
                ? ` · ${labels.missing}: ${selected.needs.join(", ")}`
                : ""}
            </small>
            {repo && (
              <a
                href={`https://github.com/${repo}/issues/${selected.number}`}
                target="_blank"
                rel="noreferrer"
              >
                {labels.openIssue} ↗
              </a>
            )}
          </div>
        ) : (
          <p>{error ?? labels.empty}</p>
        )}
      </footer>
    </section>
  );
}
