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
  /** The code module on the cell, when the field shows modules (M-2). */
  module?: HudModule | null;
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

/**
 * The detail under the round clock. On ALLOW the refusal is by definition
 * absent, so say what the round did - how many Bees run and the latest
 * dispatch - instead of printing the "no eligible specification" fallback
 * that only means anything on a refusal. Measured 2026-09-04 01:39Z: an
 * allowed tick (4 dispatched) rendered the refusal explanation.
 */
export function decisionDetail(
  decision: { allowed: boolean; refusal: string | null },
  running: number | null,
  latestIssue: number | null,
  labels: { queueMeaning: string; executing: string },
): string {
  if (decision.allowed) {
    const tail = latestIssue !== null ? ` · #${latestIssue}` : "";
    return `${running ?? "—"} ${labels.executing}${tail}`;
  }
  return decision.refusal ?? labels.queueMeaning;
}

/**
 * The A2A bootstrap names its endpoints on api.t27.ai, an origin that fails
 * TLS and 404s (measured 2026-09-04). The page itself reads from QUEEN_API,
 * so the copy hands out that origin with each endpoint's own path and query.
 */
export function rewriteEndpoints(
  endpoints: Record<string, string>,
  origin: string,
): Record<string, string> {
  const base = origin.replace(/\/+$/, "");
  const out: Record<string, string> = {};
  for (const [key, value] of Object.entries(endpoints)) {
    try {
      const url = new URL(value);
      out[key] = `${base}${url.pathname}${url.search}`;
    } catch {
      out[key] = value;
    }
  }
  return out;
}

/**
 * The one-line resolution of a round, shown for a few seconds when
 * lastTick.decidedAt changes: the clock of the tick, the verdict, what it did
 * (decisionDetail) and how many candidates it skipped. Every part is a status
 * field or a COPY key.
 */
export function roundStrip(
  decision: { decidedAt: string; allowed: boolean; refusal: string | null; skippedCount: number },
  running: number | null,
  latestIssue: number | null,
  labels: { allow: string; refuse: string; executing: string; queueMeaning: string; reasons: string },
  lang: string,
): string {
  const at = new Date(decision.decidedAt);
  const clock = Number.isNaN(at.getTime())
    ? "—"
    : at.toLocaleTimeString(lang === "ru" ? "ru-RU" : "en-GB", { hour: "2-digit", minute: "2-digit", hour12: false });
  const verdict = decision.allowed ? labels.allow : labels.refuse;
  const detail = decisionDetail(decision, running, latestIssue, labels);
  return `${clock} · ${verdict} · ${detail} · ${decision.skippedCount} ${labels.reasons}`;
}

/**
 * A skip-reason key as words. The wire sends camelCase identifiers and no
 * meaning (backlog P3-8 asks the server for one); the page spaces the words
 * and adds nothing.
 */
export function skipReasonWords(key: string): string {
  return key.replace(/([a-z0-9])([A-Z])/g, "$1 $2").toLowerCase();
}

/**
 * A hardware device's family string -> the crystal hue on the comb: gold for
 * CPU (the default), cyan for FPGA, green for GPU - the ring colours of the
 * mark as CONTEXT.md assigns them. Only the signed registry's devices are
 * drawn; nothing is invented.
 */
export function crystalOf(family: string): "cpu" | "fpga" | "gpu" {
  const f = family.toLowerCase();
  if (/fpga|xc7|artix|kintex|zynq|lattice|ice40|ecp5|wukong|nexus/.test(f)) return "fpga";
  if (/gpu|cuda|rtx|radeon|tensor core|h100|a100/.test(f)) return "gpu";
  return "cpu";
}

/**
 * The field's shape for a card count: rows of down-pointing marks, cols per
 * row. One function, so the comb, the minimap and the placement ledger agree
 * on how many cells exist (P1-20).
 */
export function fieldShape(cardCount: number): { rows: number; cols: number; cellCount: number } {
  const count = Math.max(27, cardCount);
  const rows = Math.max(3, Math.ceil(Math.sqrt(count / 1.1)));
  const cols = rows + 2;
  // buildCells keeps only the down cells: an even row holds cols of them, an
  // odd row one fewer. rows * cols overstated the count by floor(rows / 2)
  // and left that many placed slots with no cell (found by the ring order).
  return { rows, cols, cellCount: rows * cols - Math.floor(rows / 2) };
}

/**
 * Placement ledger keyed by card number. The public board is rebuilt in wire
 * order on every poll, so a positional layout moved every structure and every
 * bee whenever an issue was inserted at the head. Here a known card keeps the
 * cell it had; a card that left frees its cell; a new card takes the first
 * free cell; a cell index that no longer fits the field is re-placed. Pure:
 * the ledger passed in is never mutated, the next one is returned.
 */
export function placeCards<T extends { number: number }>(
  previous: ReadonlyMap<number, number>,
  cards: T[],
  cellCount: number,
  order?: readonly number[],
): { placed: (T | null)[]; ledger: Map<number, number> } {
  const placed: (T | null)[] = new Array<T | null>(cellCount).fill(null);
  const ledger = new Map<number, number>();
  const pending: T[] = [];
  for (const card of cards) {
    const index = previous.get(card.number);
    if (index !== undefined && index < cellCount && placed[index] === null && !ledger.has(card.number)) {
      placed[index] = card;
      ledger.set(card.number, index);
    } else if (!ledger.has(card.number)) {
      pending.push(card);
    }
  }
  const seq = order && order.length === cellCount ? order : null;
  let free = 0;
  for (const card of pending) {
    while (free < cellCount && placed[seq ? seq[free] : free] !== null) free += 1;
    if (free >= cellCount) break;
    const slot = seq ? seq[free] : free;
    placed[slot] = card;
    ledger.set(card.number, slot);
  }
  return { placed, ledger };
}

/**
 * Seconds since the last successful poll, but only once a poll has FAILED
 * after a first success: that is the moment the numbers on screen stop being
 * the wire's and the reader must be told (P1-12). Before the first success
 * there is nothing stale (the tiles read dashes); while polls succeed there is
 * nothing stale either. Null means "no badge".
 */
export function staleAge(nowMs: number, syncedAt: Date | null, error: string | null): number | null {
  if (error === null || syncedAt === null) return null;
  return Math.max(0, Math.floor((nowMs - syncedAt.getTime()) / 1000));
}

/**
 * The ring colour of a territory, RTS style: the hover ring and the
 * selection flare are coloured by whose ground it is (StarCraft II colours
 * its hover and selection circles by allegiance). Held is the swarm's green,
 * neutral the HUD's cyan, fog the cold red the feed uses for errors.
 */
export function ringTone(territory: Territory): string {
  if (territory === "held") return "#00FF88";
  if (territory === "fog") return "#FF6B6B";
  return "#64DCFF";
}

/**
 * A code module of the repository the Queen supervises: the unit of place
 * on the field (the user, 2026-09-04: "modules in rings from the centre;
 * bees are the issues"). The signature is what the visual is generated from.
 * Until /queen/public-modules exists (M-1) the rows come from
 * public/queen/modules.json, a scan of the repo stamped with its commit.
 */
export interface HudModule {
  path: string;
  depth: number;
  language: string;
  files: number;
  lines: number;
  functions: number;
  imports: number;
  exports: number;
  lastTouched: string | null;
  openIssues: number[];
}

/** FNV-1a over the path: a stable positive id, so a module can be a card. */
export function moduleId(path: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < path.length; i += 1) {
    h ^= path.charCodeAt(i);
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return (h % 2147483646) + 1;
}

const DAY = 86_400_000;

/**
 * The column a module stands in, from facts: an open issue in progress on
 * it makes it "running"; any open issue "review"; touched within 30 days
 * "done" (alive); untouched for 180 days "dropped" (dormant); else backlog.
 * Territory then follows territoryOf as for a card.
 */
export function moduleColumn(m: HudModule, nowMs: number, running: ReadonlySet<number>): string {
  if (m.openIssues.some((n) => running.has(n))) return "running";
  if (m.openIssues.length > 0) return "review";
  const touched = m.lastTouched ? Date.parse(m.lastTouched) : NaN;
  if (Number.isFinite(touched)) {
    const age = nowMs - touched;
    if (age <= 30 * DAY) return "done";
    if (age >= 180 * DAY) return "dropped";
  }
  return "backlog";
}

export function moduleCard(m: HudModule, nowMs: number, running: ReadonlySet<number>): HudCard {
  return { number: moduleId(m.path), title: m.path, column: moduleColumn(m, nowMs, running), criteria: m.files };
}

/** The module a file path belongs to: the longest module path that prefixes it. */
export function moduleFor(filePath: string, modules: readonly HudModule[]): HudModule | null {
  const rel = filePath.startsWith("trios/") ? filePath.slice(6) : filePath;
  let best: HudModule | null = null;
  for (const m of modules) {
    if (m.path === "." || rel === m.path || rel.startsWith(m.path + "/")) {
      if (!best || m.path.length > best.path.length) best = m;
    }
  }
  return best;
}

/** The first path-like token in a title, if any (issue titles name files). */
export function pathInTitle(title: string): string | null {
  const m = /(?<![\w.])((?:[A-Za-z0-9_.-]+\/){1,}[A-Za-z0-9_.-]+)/.exec(title);
  return m ? m[1] : null;
}

/**
 * The same layout buildCells uses (rows of down cells, cols per row): cell
 * centres for a card count, so a ring order can be computed before anything
 * is placed. Kept in step with QueenComb's buildCells by the honesty contract.
 */
export function cellGeometry(cardCount: number): Array<{ x: number; y: number }> {
  const { rows, cols } = fieldShape(cardCount);
  const S = 150;
  const HH = (S * Math.sqrt(3)) / 2;
  const out: Array<{ x: number; y: number }> = [];
  for (let r = 0; r < rows; r += 1) {
    for (let c = 0; c < cols * 2 - 1; c += 1) {
      if (((c + r) & 1) === 1) continue;
      out.push({ x: (c - (cols * 2 - 2) / 2) * (S / 2), y: (r - rows / 2) * HH + HH / 3 });
    }
  }
  return out;
}

/**
 * Rings from the centre (the Flower of Life): cell indices by distance from
 * the home cell, home first. The placement ledger takes free cells in this
 * order, so the first modules stand nearest the Queen and later ones grow
 * the base outward.
 */
export function ringOrder(cells: ReadonlyArray<{ x: number; y: number }>, home: number): number[] {
  const h = cells[home];
  if (!h) return cells.map((_, i) => i);
  return cells
    .map((c, i) => ({ i, d: (c.x - h.x) ** 2 + (c.y - h.y) ** 2 }))
    .sort((a, b) => a.d - b.d || a.i - b.i)
    .map((e) => e.i);
}
