import { useLayoutEffect, useMemo, useRef } from "react";
import type { HudEvent, HudEventKind, SectorRow, Territory } from "./queenHud";
import { eventTone , feedCoverage } from "./queenHud";
import { publicIssueTitle } from "../pages/queenReviewLifecycle";
import "./QueenIntel.css";

// The right column of the one-screen HUD: the INTEL FEED (public-activity,
// newest first, the only thing in the column that scrolls) and the SECTORS
// panel (the six board columns as territories). Neither panel owns data:
// the feed prints exactly the events the page fetched, the sectors print
// exactly the rows sectorRows() derived from the board. There is no public
// write endpoint, so nothing here acts on the Queen - a sector row is a
// selection, the footer button toggles the panel, an event row is a link.

// ---- INTEL FEED -----------------------------------------------------------

export interface IntelLabels {
  title: string;
  live: string;
  offline: string;
  empty: string;
  viewAll: string;
  collapse: string;
  /** the header's own count and span words (P1-27) */
  rows: string;
  unitS: string;
  unitMin: string;
  unitH: string;
  spanTitle: string;
}

export interface QueenIntelFeedProps {
  events: HudEvent[];
  error: string | null;
  lang: string;
  repo: string | null;
  expanded: boolean;
  onToggle: () => void;
  describe: (event: HudEvent) => string;
  labels: IntelLabels;
}

function glyphOf(kind: HudEventKind): string {
  switch (kind) {
    case "review":
      return "▲";
    case "error":
      return "✕";
    case "finished":
    case "result":
      return "✓";
    case "dispatch":
      return "◆";
    case "progress":
      return "●";
    case "tool":
      return "▸";
    default:
      return "∙";
  }
}

function localeOf(lang: string): string {
  return lang === "ru" ? "ru-RU" : "en-GB";
}

/** HH:MM:SS in the page locale; the raw ISO string when it does not parse. */
function stampOf(clock: Intl.DateTimeFormat, at: string): string {
  const ms = new Date(at).getTime();
  return Number.isFinite(ms) ? clock.format(ms) : at;
}

/**
 * Where the reader is looking: the first row that crosses the top edge of
 * the scroller, and how far above it the edge sits. The list is newest-first
 * and reflows every poll, so scrollTop alone drifts; an anchored row does not.
 */
interface ScrollAnchor {
  id: string;
  offset: number;
}

function anchorOf(list: HTMLOListElement): ScrollAnchor | null {
  const top = list.scrollTop;
  if (top <= 0) return null;
  for (const child of list.children) {
    const row = child as HTMLElement;
    if (row.offsetTop + row.offsetHeight > top) {
      const id = row.dataset.id;
      return id ? { id, offset: row.offsetTop - top } : null;
    }
  }
  return null;
}

function rowById(list: HTMLOListElement, id: string): HTMLElement | null {
  for (const child of list.children) {
    const row = child as HTMLElement;
    if (row.dataset.id === id) return row;
  }
  return null;
}

interface IntelRowProps {
  event: HudEvent;
  lang: string;
  repo: string | null;
  clock: Intl.DateTimeFormat;
  describe: (event: HudEvent) => string;
}

function IntelRow({ event, lang, repo, clock, describe }: IntelRowProps) {
  const tone = eventTone(event.kind);
  const headline = `${describe(event)}${event.issue ? ` · #${event.issue}` : ""}`;
  const subtitle = publicIssueTitle(event.title, event.issue ?? 0, lang);
  const href =
    event.issue && repo ? `https://github.com/${repo}/issues/${event.issue}` : null;
  const body = (
    <>
      <span className="queen27-intel-glyph" data-tone={tone} aria-hidden="true">
        {glyphOf(event.kind)}
      </span>
      <span className="queen27-intel-text">
        <b>{headline}</b>
        <span>{subtitle}</span>
      </span>
      <time dateTime={event.at}>{stampOf(clock, event.at)}</time>
    </>
  );
  return (
    <li className="queen27-intel-row" data-id={event.id}>
      {href ? (
        <a className="queen27-intel-link" href={href} target="_blank" rel="noreferrer">
          {body}
        </a>
      ) : (
        <div className="queen27-intel-link">{body}</div>
      )}
    </li>
  );
}

export function QueenIntelFeed({
  events,
  error,
  lang,
  repo,
  expanded,
  onToggle,
  describe,
  labels,
}: QueenIntelFeedProps) {
  const listRef = useRef<HTMLOListElement | null>(null);
  const anchorRef = useRef<ScrollAnchor | null>(null);
  // the header states what the list holds, from the rows themselves (P1-27)
  const coverage = useMemo(() => feedCoverage(events), [events]);
  const spanText =
    coverage.spanSeconds === null
      ? null
      : coverage.spanSeconds < 60
        ? `${coverage.spanSeconds} ${labels.unitS}`
        : coverage.spanSeconds < 3600
          ? `${Math.round(coverage.spanSeconds / 60)} ${labels.unitMin}`
          : `${Math.floor(coverage.spanSeconds / 3600)} ${labels.unitH} ${Math.round((coverage.spanSeconds % 3600) / 60)} ${labels.unitMin}`;

  const clock = useMemo(
    () =>
      new Intl.DateTimeFormat(localeOf(lang), {
        hour: "2-digit",
        minute: "2-digit",
        second: "2-digit",
        hourCycle: "h23",
      }),
    [lang],
  );
  const coverageTitle =
    coverage.oldestAt && coverage.newestAt && coverage.spanSeconds !== null
      ? `${labels.spanTitle} ${clock.format(new Date(coverage.oldestAt))} – ${clock.format(new Date(coverage.newestAt))}`
      : null;

  // Before paint of a commit that changed the list: put the anchored row
  // back where the reader left it, then re-anchor for the next commit. The
  // anchor itself is captured on scroll, so this touches only the ref.
  useLayoutEffect(() => {
    const list = listRef.current;
    if (!list) return;
    const anchor = anchorRef.current;
    if (anchor && list.scrollTop > 0) {
      const row = rowById(list, anchor.id);
      if (row) list.scrollTop = row.offsetTop - anchor.offset;
    }
    anchorRef.current = anchorOf(list);
  }, [events, lang]);

  return (
    <section className="queen27-intel" aria-label={labels.title}>
      <header
        className="queen27-intel-head"
        data-rows={coverage.rows}
        data-span-seconds={coverage.spanSeconds ?? undefined}
      >
        <span>{labels.title}</span>
        {error ? (
          <span className="queen27-intel-live is-offline" title={error}>
            {labels.offline}
          </span>
        ) : (
          <span className="queen27-intel-live" title={coverageTitle ?? undefined}>
            {labels.live}
            {coverage.rows > 0 ? ` · ${coverage.rows} ${labels.rows}` : ""}
            {coverage.spanSeconds !== null ? ` · ${spanText}` : ""}
          </span>
        )}
      </header>
      {events.length === 0 ? (
        <p className="queen27-intel-empty">{labels.empty}</p>
      ) : (
        <ol
          className="queen27-intel-list"
          ref={listRef}
          onScroll={(e) => {
            anchorRef.current = anchorOf(e.currentTarget);
          }}
        >
          {events.map((event) => (
            <IntelRow
              key={event.id}
              event={event}
              lang={lang}
              repo={repo}
              clock={clock}
              describe={describe}
            />
          ))}
        </ol>
      )}
      <footer className="queen27-intel-foot">
        <button type="button" onClick={onToggle} aria-expanded={expanded}>
          {expanded ? labels.collapse : labels.viewAll} ›
        </button>
      </footer>
    </section>
  );
}

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
