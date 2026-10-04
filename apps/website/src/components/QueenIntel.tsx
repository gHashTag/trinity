import type { SectorRow, Territory } from "./queenHud";
import "./QueenIntel.css";

// The SECTORS panel: the six board columns as territories. It owns no data --
// it prints exactly the rows sectorRows() derived from the board. There is no
// public write endpoint, so nothing here acts on the Queen; a sector row is a
// selection and nothing more.
//
// This file also held the INTEL FEED, the public-activity list that filled the
// rest of the right column. The shell gave that cell to the Queen's own
// conversation in 9316e9edd (2026-09-08) and the component was left behind,
// exported and imported by nobody, for two weeks. It is gone now.

// ---- SECTORS --------------------------------------------------------------

export interface SectorLabels {
  title: string;
  held: string;
  neutral: string;
  fog: string;
  cards: string;
}

export interface QueenSectorsProps {
  /** null until the board has answered once: the panel reads a dash, never six zeros */
  rows: SectorRow[] | null;
  active: string | null;
  onSelect?: (key: string) => void;
  labels: SectorLabels;
}

function territoryGlyph(territory: Territory): string {
  switch (territory) {
    case "held":
      return "◆";
    case "neutral":
      return "◇";
    default:
      return "▽";
  }
}

export function QueenSectors({ rows, active, onSelect, labels }: QueenSectorsProps) {
  return (
    <section className="queen27-sectors" aria-label={labels.title}>
      <header className="queen27-sectors-head">
        <span>{labels.title}</span>
      </header>
      <ul className="queen27-sectors-list">
        {rows === null ? (
          <li className="queen27-sectors-empty">—</li>
        ) : rows.map((row) => {
          const share = Math.min(1, Math.max(0, row.share));
          return (
            <li key={row.key}>
              <button
                type="button"
                className="queen27-sectors-row"
                data-territory={row.territory}
                aria-pressed={active === row.key}
                onClick={() => onSelect?.(row.key)}
              >
                <span className="queen27-sectors-glyph" aria-hidden="true">
                  {territoryGlyph(row.territory)}
                </span>
                <span className="queen27-sectors-title">{row.title}</span>
                <span className="queen27-sectors-territory">{labels[row.territory]}</span>
                <span className="queen27-sectors-count">
                  {row.count}
                  <small>{labels.cards}</small>
                </span>
                <span className="queen27-sectors-bar">
                  <span style={{ width: `${share * 100}%` }} />
                </span>
              </button>
            </li>
          );
        })}
      </ul>
    </section>
  );
}
