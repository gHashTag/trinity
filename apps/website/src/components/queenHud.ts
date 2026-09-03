// The single-screen Queen HUD: the one contract every panel imports.
//
// Nothing here fetches, renders or guesses. Every type mirrors a field the
// page already receives from the five public endpoints (status, public-board,
// public-activity, public-research, public-hardware), and every helper is a
// pure function of those fields. If a panel needs a number that is not
// derivable from these types, the number does not exist yet and the panel
// must say so rather than invent it.

export type HudView = "comb" | "kanban" | "map" | "factory" | "research";
export const HUD_VIEWS: readonly HudView[] = [
  "comb",
  "kanban",
  "map",
  "factory",
  "research",
] as const;

export type Territory = "held" | "neutral" | "fog";

export interface HudColumn {
  key: string;
  title: string;
  blurb: string;
}

export interface HudCard {
  number: number;
  title: string;
  column: string;
  criteria?: number;
  needs?: string[];
}

export interface HudWorkers {
  capacity: number;
  active: number;
  idle: number;
  utilization: number;
  slots: Array<{ slot: number; state: "busy" | "idle" }>;
}

export type HudEventKind =
  | "dispatch"
  | "progress"
  | "tool"
  | "result"
  | "usage"
  | "error"
  | "finished"
  | "review";

export interface HudEvent {
  id: string;
  kind: HudEventKind;
  issue: number | null;
  title: string;
  at: string;
  state: string | null;
}

export type BeeLine = "scribe" | "wright" | "lapidary";

/** What the comb reports when a cell is clicked. The centre cell is the Queen's. */
export interface HudPick {
  index: number;
  isQueen: boolean;
  territory: Territory;
  card: HudCard | null;
  bee: { slot: number; line: BeeLine; busy: boolean } | null;
}

/** Imperative handle the shell uses to drive the comb's camera. */
export interface CombHandle {
  zoomIn(): void;
  zoomOut(): void;
  /** Reset yaw, pitch and distance to the defaults and resume the slow auto-orbit. */
  fit(): void;
}

/** A read-only view of the field for the minimap: one entry per cell. */
export interface CombCellSummary {
  x: number;
  y: number;
  yTop: number;
  up: boolean;
  own: Territory;
  cardNumber: number | null;
}

// Which column means which ground. done/running: the swarm holds it. backlog
// and review: reachable, unclaimed. blocked/dropped: fog - nothing to scout.
// Identical to the comb's own rule; the comb imports this one.
export function territoryOf(column: string): Territory {
  if (column === "done" || column === "running") return "held";
  if (column === "blocked" || column === "dropped") return "fog";
  return "neutral";
}

/** Colour role of an event kind. Resolved to the live palette in Queen.css. */
export type Tone = "gold" | "cold" | "green" | "cyan" | "muted";

export function eventTone(kind: HudEventKind): Tone {
  switch (kind) {
    case "review":
      return "gold";
    case "error":
      return "cold";
    case "finished":
    case "result":
      return "green";
    case "dispatch":
    case "progress":
      return "cyan";
    default:
      return "muted";
  }
}

/** One row of the sectors panel: a board column as a territory with its share. */
export interface SectorRow {
  key: string;
  title: string;
  count: number;
  territory: Territory;
  /** count / total cards, 0..1; 0 when the board is empty. */
  share: number;
}

export function sectorRows(columns: HudColumn[], cards: HudCard[]): SectorRow[] {
  const total = cards.length;
  return columns.map((column) => {
    const count = cards.filter((card) => card.column === column.key).length;
    return {
      key: column.key,
      title: column.title,
      count,
      territory: territoryOf(column.key),
      share: total > 0 ? count / total : 0,
    };
  });
}

/** The window the bell counts over. The activity feed's own buffer is capped
 *  by count, not by time, so the shell keeps alert-kind events in a second
 *  buffer evicted by this window; the two must agree on it. */
export const ALERT_WINDOW_MS = 60 * 60 * 1_000;

/** The kinds that deserve the bell: verdicts, errors, finishes. */
export function isAlertKind(kind: HudEventKind): boolean {
  return kind === "review" || kind === "error" || kind === "finished";
}

/** Events in the last window whose kind deserves the bell. */
export function alertCount(
  events: HudEvent[],
  now: number,
  windowMs = ALERT_WINDOW_MS,
): number {
  return events.filter((event) => {
    if (!isAlertKind(event.kind)) return false;
    const at = new Date(event.at).getTime();
    return Number.isFinite(at) && now - at <= windowMs;
  }).length;
}

/** The latest event recorded for an issue, or null. */
export function latestEventFor(events: HudEvent[], issue: number): HudEvent | null {
  let best: HudEvent | null = null;
  for (const event of events) {
    if (event.issue !== issue) continue;
    if (!best || new Date(event.at).getTime() > new Date(best.at).getTime()) best = event;
  }
  return best;
}
