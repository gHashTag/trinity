import { useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { publicIssueTitle } from "../pages/queenReviewLifecycle";
import type { HudCard, HudColumn, HudEvent, HudPick } from "./queenHud";
import "./QueenContext.css";

// The floating CONTEXT DETAILS panel over the bottom of the centre viewport:
// the 4X unit/queue card. Left: the running bees (or, when none run, the
// review queue) straight from the board's columns and the activity feed.
// Right: whatever the comb reports as picked - the Queen by default, a cell
// otherwise. Every figure here is an endpoint field; there is no per-bee
// progress figure on the wire, so there is no progress bar.

export interface QueenContextLabels {
  title: string;
  queue: string;
  queueEmpty: string;
  reviewQueue: string;
  last: string;
  selected: string;
  theQueen: string;
  queenRole: string;
  backend: string;
  live: string;
  offline: string;
  accepted: string;
  verdicts: string;
  bees: string;
  rounds: string;
  beesStarted: string;
  sector: string;
  territory: string;
  held: string;
  neutral: string;
  fog: string;
  criteria: string;
  needs: string;
  noBee: string;
  slot: string;
  busy: string;
  idle: string;
  cell: string;
  dispatched: string;
  openIssue: string;
  copyLink: string;
  linkCopied: string;
  close: string;
  openPanel: string;
}

export interface QueenContextQueueItem {
  card: HudCard;
  latest: HudEvent | null;
}

export interface QueenContextDispatch {
  issue: number;
  dispatchedAt: string;
  outcome: string | null;
  finishedAt: string | null;
}

/** Every figure is null until its endpoint has answered; null renders "—". */
export interface QueenContextQueenStats {
  backendLive: boolean;
  accepted: number | null;
  verdicts: number | null;
  running: number | null;
  capacity: number | null;
  rounds: number | null;
  beesStarted: number | null;
}

export interface QueenContextProps {
  open: boolean;
  onClose: () => void;
  onOpen: () => void;
  lang: string;
  repo: string | null;
  columns: HudColumn[];
  /** null while the board has not answered: "no Bee running" is a board fact. */
  queue: QueenContextQueueItem[] | null;
  reviewQueue: HudCard[];
  latestDispatch: QueenContextDispatch | null;
  pick: HudPick | null;
  queenStats: QueenContextQueenStats;
  describe: (event: HudEvent) => string;
  labels: QueenContextLabels;
}

type CopyState = "idle" | "copied" | "error";

function localeOf(lang: string) {
  return lang === "ru" ? "ru-RU" : "en-GB";
}

/** HH:MM:SS of an ISO timestamp, or an em dash when it does not parse. */
function clock(value: string, lang: string) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "—";
  return date.toLocaleTimeString(localeOf(lang), {
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
  });
}

/** dd MMM HH:mm of an ISO timestamp, or an em dash. */
function moment(value: string | null, lang: string) {
  if (!value) return "—";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "—";
  return new Intl.DateTimeFormat(localeOf(lang), {
    day: "2-digit",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
}

function issueUrl(repo: string | null, number: number | null | undefined) {
  if (!repo || number == null) return null;
  return `https://github.com/${repo}/issues/${number}`;
}

async function copyToClipboard(value: string) {
  // Synchronous user-gesture path first; the async clipboard bridge is the
  // fallback because some embedded browsers leave writeText pending forever.
  const area = document.createElement("textarea");
  area.value = value;
  area.style.position = "fixed";
  area.style.opacity = "0";
  document.body.appendChild(area);
  area.select();
  const copied = document.execCommand("copy");
  area.remove();
  if (copied) return;
  if (navigator.clipboard?.writeText) {
    await navigator.clipboard.writeText(value);
    return;
  }
  throw new Error("Clipboard is unavailable");
}

function IssueRow({
  href,
  className,
  children,
}: {
  href: string | null;
  className: string;
  children: ReactNode;
}) {
  if (href) {
    return (
      <a className={className} href={href} target="_blank" rel="noreferrer">
        {children}
      </a>
    );
  }
  return <div className={className}>{children}</div>;
}

export function QueenContext({
  open,
  onClose,
  onOpen,
  lang,
  repo,
  columns,
  queue,
  reviewQueue,
  latestDispatch,
  pick,
  queenStats,
  describe,
  labels,
}: QueenContextProps) {
  const [copyState, setCopyState] = useState<CopyState>("idle");
  const copyTimer = useRef<number | null>(null);

  useEffect(
    () => () => {
      if (copyTimer.current !== null) window.clearTimeout(copyTimer.current);
    },
    [],
  );

  const showQueen = !pick || pick.isQueen;
  const card = showQueen ? null : pick.card;
  const selectedUrl = useMemo(() => issueUrl(repo, card?.number), [repo, card]);

  const sectorTitle = useMemo(() => {
    if (!card) return "—";
    return columns.find((column) => column.key === card.column)?.title ?? card.column;
  }, [columns, card]);

  const portrait = useMemo(() => {
    if (showQueen) return "./queen/portrait-queen-256.png";
    if (pick.bee && pick.bee.busy) return `./queen/portrait-${pick.bee.line}-256.png`;
    if (pick.bee) return "./queen/larva-256.png";
    return `./queen/ground-${pick.territory}-256.png`;
  }, [showQueen, pick]);

  // The slot number and its busy/idle state are the research endpoint's
  // worker fields. The bee's caste is the sprite's, not the wire's, so it is
  // drawn and never written.
  const unitName = useMemo(() => {
    if (showQueen) return null;
    if (pick.bee) {
      const slot = String(pick.bee.slot).padStart(2, "0");
      return `${labels.slot} ${slot} · ${pick.bee.busy ? labels.busy : labels.idle}`;
    }
    return labels.noBee;
  }, [showQueen, pick, labels.slot, labels.busy, labels.idle, labels.noBee]);

  if (!open) {
    return (
      <button type="button" className="queen27-context-chip" onClick={onOpen}>
        {labels.openPanel} ▴
      </button>
    );
  }

  const handleCopy = async () => {
    if (!selectedUrl) return;
    if (copyTimer.current !== null) window.clearTimeout(copyTimer.current);
    try {
      await copyToClipboard(selectedUrl);
      setCopyState("copied");
      copyTimer.current = window.setTimeout(() => {
        copyTimer.current = null;
        setCopyState("idle");
      }, 2_500);
    } catch {
      setCopyState("error");
    }
  };

  const territoryLabel = pick && !showQueen ? labels[pick.territory] : null;

  return (
    <section className="queen27-context" role="dialog" aria-label={labels.title}>
      <header className="queen27-context-head">
        <span>{labels.title}</span>
        <button type="button" onClick={onClose} aria-label={labels.close}>
          ×
        </button>
      </header>
      <div className="queen27-context-body">
        <div className="queen27-context-col">
          <h3 className="queen27-context-heading">{labels.queue}</h3>
          {queue === null ? (
            <p className="queen27-context-empty">—</p>
          ) : queue.length > 0 ? (
            <ul className="queen27-context-rows">
              {queue.map(({ card: item, latest }) => (
                <li key={item.number}>
                  <IssueRow
                    href={issueUrl(repo, item.number)}
                    className="queen27-context-row is-running"
                  >
                    <i aria-hidden="true">◆</i>
                    <b>#{item.number}</b>
                    <strong>{publicIssueTitle(item.title, item.number, lang)}</strong>
                    <small>
                      {latest ? `${describe(latest)} · ${clock(latest.at, lang)}` : "—"}
                    </small>
                  </IssueRow>
                </li>
              ))}
            </ul>
          ) : (
            <>
              <p className="queen27-context-empty">{labels.queueEmpty}</p>
              <h3 className="queen27-context-heading">{labels.reviewQueue}</h3>
              {reviewQueue.length > 0 && (
                <ul className="queen27-context-rows">
                  {reviewQueue.map((item) => (
                    <li key={item.number}>
                      <IssueRow
                        href={issueUrl(repo, item.number)}
                        className="queen27-context-row is-review"
                      >
                        <i aria-hidden="true">◇</i>
                        <b>#{item.number}</b>
                        <strong>{publicIssueTitle(item.title, item.number, lang)}</strong>
                      </IssueRow>
                    </li>
                  ))}
                </ul>
              )}
              {latestDispatch && (
                <small className="queen27-context-last">
                  {labels.last}: #{latestDispatch.issue} ·{" "}
                  {latestDispatch.finishedAt
                    ? `${latestDispatch.outcome ? latestDispatch.outcome.toUpperCase() : "—"} · ${moment(latestDispatch.finishedAt, lang)}`
                    : `${labels.dispatched} ${moment(latestDispatch.dispatchedAt, lang)}`}
                </small>
              )}
            </>
          )}
        </div>

        <div className="queen27-context-col queen27-context-selected">
          <h3 className="queen27-context-heading">{labels.selected}</h3>
          <div className="queen27-context-unit">
            <span className="queen27-context-portrait">
              <img src={portrait} alt="" loading="lazy" width={96} height={96} />
            </span>
            <div className="queen27-context-unit-text">
              {showQueen ? (
                <>
                  <b>T27: {labels.theQueen}</b>
                  <small>{labels.queenRole}</small>
                </>
              ) : (
                <b>{unitName}</b>
              )}
            </div>
          </div>

          {showQueen ? (
            <dl className="queen27-context-stats">
              <dt>{labels.backend}</dt>
              <dd className={queenStats.backendLive ? "is-green" : "is-cold"}>
                {queenStats.backendLive ? labels.live : labels.offline}
              </dd>
              <dt>{labels.accepted}</dt>
              <dd>{queenStats.accepted ?? "—"}</dd>
              <dt>{labels.verdicts}</dt>
              <dd>{queenStats.verdicts ?? "—"}</dd>
              <dt>{labels.bees}</dt>
              <dd>
                {queenStats.running !== null && queenStats.capacity !== null
                  ? `${queenStats.running}/${queenStats.capacity}`
                  : "—"}
              </dd>
              <dt>{labels.rounds}</dt>
              <dd>{queenStats.rounds ?? "—"}</dd>
              <dt>{labels.beesStarted}</dt>
              <dd>{queenStats.beesStarted ?? "—"}</dd>
            </dl>
          ) : (
            <>
              <dl className="queen27-context-stats">
                {/* the card is the cell's, under its own label: a bee drawn
                    over a cell is a sprite in flight, not an assignment */}
                {card && (
                  <>
                    <dt>{labels.cell}</dt>
                    <dd title={`#${card.number} · ${publicIssueTitle(card.title, card.number, lang)}`}>
                      #{card.number} · {publicIssueTitle(card.title, card.number, lang)}
                    </dd>
                  </>
                )}
                <dt>{labels.sector}</dt>
                <dd>{sectorTitle}</dd>
                <dt>{labels.territory}</dt>
                <dd className={`is-${pick.territory}`}>{territoryLabel}</dd>
                <dt>{labels.criteria}</dt>
                <dd>{card?.criteria ?? "—"}</dd>
                <dt>{labels.needs}</dt>
                <dd>{card?.needs && card.needs.length > 0 ? card.needs.join(", ") : "—"}</dd>
              </dl>
              <div className="queen27-context-actions">
                {selectedUrl && (
                  <a href={selectedUrl} target="_blank" rel="noreferrer">
                    {labels.openIssue}
                  </a>
                )}
                <button
                  type="button"
                  onClick={handleCopy}
                  disabled={!selectedUrl}
                  className={copyState === "copied" ? "is-copied" : undefined}
                >
                  {copyState === "copied" ? labels.linkCopied : labels.copyLink}
                </button>
              </div>
            </>
          )}
        </div>
      </div>
    </section>
  );
}
