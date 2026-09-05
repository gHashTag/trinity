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

/**
 * An event's identity (P0-10). The wire stamps a review verdict anew every
 * round it stays pending (`review-<issue>-<tick stamp>-<n>`), so by id the
 * same verdict is a fresh alert, feed row and glint every five minutes. A
 * verdict is the pair (issue, state): the identity changes only when the
 * state does. Every other kind keeps its wire id.
 */
export function eventIdentity(event: { id: string; kind: HudEventKind; issue: number | null; state: string | null }): string {
  return event.kind === "review" && event.issue !== null ? `review:${event.issue}:${event.state ?? ""}` : event.id;
}

/** Events in the last window whose kind deserves the bell. */
export function alertCount(
  events: HudEvent[],
  now: number,
  windowMs = ALERT_WINDOW_MS,
): number {
  const identities = new Set<string>();
  for (const event of events) {
    if (!isAlertKind(event.kind)) continue;
    const at = new Date(event.at).getTime();
    if (Number.isFinite(at) && now - at <= windowMs) identities.add(eventIdentity(event));
  }
  return identities.size;
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

/**
 * The shape grammar (M-3): a module's building as a list of parts, a pure
 * function of its signature, so the same code always yields the same
 * building and a different module a different one. Parts are Kenney models
 * the field already loads, placed around the core in the core's frame:
 * - core: by language; footprint by lines (log scale); height by function
 *   density (functions per hundred lines), stretched up to 1.6x;
 * - wings: one annex platform per export band (0..3), on the core's sides;
 * - antennae: one dish per import band (0..3), on the core's corners;
 * - the whole building turned a quarter per the path's hash;
 * - an open issue adds the red fence (drawn by the field, not a part).
 */
export interface BuildingPart {
  model: "core" | "annex" | "antenna" | "band";
  dx: number;
  dz: number;
  scale: number;
  height: number;
  /** for a window band: its level up the core, 1..3 */
  level?: number;
}
export interface BuildingPlan {
  core: string;
  turn: number;
  parts: BuildingPart[];
}
const CORE_BY_LANGUAGE: Record<string, string> = { typescript: "done", javascript: "doneDepot", swift: "doneDepot", rust: "doneSilo", zig: "running", python: "review", shell: "backlog", go: "doneSilo" };
const band = (n: number, steps: number[]) => steps.filter((t) => n >= t).length;

export function buildingPlan(m: HudModule): BuildingPlan {
  const scale = 0.85 + 0.55 * Math.min(1, Math.log10(Math.max(1, m.lines)) / 4.5);
  const density = m.lines > 0 ? (m.functions / m.lines) * 100 : 0;
  const height = 1 + Math.min(0.6, density / 12);
  const wings = band(m.exports, [8, 30, 90]);
  const antennae = band(m.imports, [10, 40, 120]);
  const parts: BuildingPart[] = [{ model: "core", dx: 0, dz: 0, scale, height }];
  const sides: Array<[number, number]> = [[1, 0], [-1, 0], [0, 1]];
  for (let i = 0; i < wings; i += 1) parts.push({ model: "annex", dx: sides[i][0] * 0.62, dz: sides[i][1] * 0.62, scale: scale * 0.45, height: 1 });
  const corners: Array<[number, number]> = [[0.55, -0.55], [-0.55, -0.55], [0.55, 0.55]];
  for (let i = 0; i < antennae; i += 1) parts.push({ model: "antenna", dx: corners[i][0], dz: corners[i][1], scale: scale * 0.3, height: 1 });
  // lit window bands up the core: one per function band (0..3), so a module
  // with many functions reads as a busy building at night
  const bands = band(m.functions, [40, 160, 500]);
  for (let i = 0; i < bands; i += 1) parts.push({ model: "band", dx: 0, dz: 0, scale: scale * 0.72, height, level: i + 1 });
  return { core: CORE_BY_LANGUAGE[m.language] ?? "dropped", turn: (moduleId(m.path) % 4) * (Math.PI / 2), parts };
}

/**
 * The per-instance tint (M-4): the material reads it per building, so no
 * two modules of one language and size look alike. Recency warms and
 * brightens (touched within a week: warm white; within a month: neutral;
 * dormant half a year: cold and dim); every open issue wears the paint down
 * a step. RGBA in 0..1, multiplied onto the model's palette.
 */
export function buildingTint(m: HudModule, nowMs: number): [number, number, number, number] {
  const touched = m.lastTouched ? Date.parse(m.lastTouched) : NaN;
  const age = Number.isFinite(touched) ? (nowMs - touched) / DAY : 365;
  let r = 0.62, g = 0.66, b = 0.78;
  if (age <= 7) { r = 1.0; g = 0.96; b = 0.86; }
  else if (age <= 30) { r = 0.9; g = 0.9; b = 0.9; }
  else if (age <= 180) { r = 0.76; g = 0.78; b = 0.84; }
  const wear = Math.max(0.55, 1 - 0.12 * Math.min(3, m.openIssues.length));
  return [r * wear, g * wear, b * wear, 1];
}

/** A stable hash of a plan: the contract that the same signature yields the same building. */
export function planHash(plan: BuildingPlan): number {
  const text = plan.core + "|" + plan.turn.toFixed(4) + "|" + plan.parts.map((p) => `${p.model}:${p.dx.toFixed(3)},${p.dz.toFixed(3)},${p.scale.toFixed(4)},${p.height.toFixed(4)}`).join(";");
  return moduleId(text);
}

/**
 * The server does not know issues; the board does. A module's open issues
 * are the cards (not done, not dropped) whose title names a path inside it,
 * so the wire's rows and the loop's snapshot carry the same field (M-1).
 */
export function withOpenIssues(modules: readonly HudModule[], cards: ReadonlyArray<{ number: number; title: string; column: string }>): HudModule[] {
  const open = new Map<string, number[]>();
  for (const card of cards) {
    if (card.column === "done" || card.column === "dropped") continue;
    const p = pathInTitle(card.title);
    const m = p ? moduleFor(p, modules) : null;
    if (!m) continue;
    const list = open.get(m.path) ?? [];
    if (!list.includes(card.number)) list.push(card.number);
    open.set(m.path, list);
  }
  return modules.map((m) => ({ ...m, openIssues: (open.get(m.path) ?? []).slice().sort((a, b) => a - b) }));
}

/**
 * The server's clock, from the Date header of a status answer (RFC 7231:
 * whole seconds, the moment the response was generated). offset = server -
 * client at receipt, so serverNow = clientNow + offset. A client whose clock
 * runs two minutes fast would otherwise read every round as OVERDUE two
 * minutes early (P1-30). Null when the header is absent or unparsable: the
 * countdown then trusts the client clock, as before, and says nothing false.
 * Whole-second resolution and a no-store answer (Date is generation time,
 * not delivery time) are the header's limits; the clock shows whole seconds.
 */
export function serverOffsetMs(dateHeader: string | null, sentAtMs: number, receivedAtMs: number = sentAtMs): number | null {
  if (!dateHeader) return null;
  const t = Date.parse(dateHeader);
  if (!Number.isFinite(t)) return null;
  // NTP's estimate: the server stamped the answer about half a round trip
  // after the request left, so the client's matching instant is the midpoint
  return t - (sentAtMs + receivedAtMs) / 2;
}

/**
 * The round clock, server-relative: seconds elapsed since the last round as
 * the server would count them. `known` is false without a round length or
 * a last round; `overdue` when the round length has passed.
 */
export function countdownFor(clientNowMs: number, offsetMs: number | null, lastRoundAt: string | null, roundSeconds: number): { known: boolean; elapsed: number; overdue: boolean; remaining: number } {
  if (!lastRoundAt || !(roundSeconds > 0)) return { known: false, elapsed: 0, overdue: false, remaining: 0 };
  const last = Date.parse(lastRoundAt);
  if (!Number.isFinite(last)) return { known: false, elapsed: 0, overdue: false, remaining: 0 };
  const serverNow = clientNowMs + (offsetMs ?? 0);
  const elapsed = Math.max(0, (serverNow - last) / 1000);
  return { known: true, elapsed, overdue: elapsed > roundSeconds, remaining: Math.max(0, roundSeconds - elapsed) };
}

/**
 * The activity buffer after a poll (P0-9). Pure: the newest poll's events
 * first in the wire's own order, then the events only the previous buffer
 * held; a stable sort by time, newest first, so same-second ties keep the
 * newest poll's order (Array.prototype.sort is stable) instead of letting the
 * older copy win; an event present in both (by identity, see eventIdentity)
 * keeps the newest copy; the feed
 * keeps `cap` events by count, the bell's alerts keep the window by age
 * against `nowMs` (no clock is read here).
 */
export function mergeActivity<E extends { id: string; kind: HudEventKind; at: string; issue: number | null; state: string | null }>(
  previous: { events: E[]; alerts: E[]; observedFrom?: string | null } | null,
  next: { cursor: number; events: E[] },
  nowMs: number,
  cap = 120,
  windowMs = ALERT_WINDOW_MS,
): { cursor: number; events: E[]; alerts: E[]; observedFrom: string | null } {
  const time = (event: E) => {
    const t = Date.parse(event.at);
    return Number.isFinite(t) ? t : Number.NEGATIVE_INFINITY;
  };
  // identity, not id: a verdict re-stamped by the tick replaces its older row (P0-10)
  const newest = new Set(next.events.map(eventIdentity));
  const ordered = [...next.events, ...(previous?.events ?? []).filter((event) => !newest.has(eventIdentity(event)))];
  const seen = new Set<string>();
  const events = ordered
    .filter((event) => (seen.has(eventIdentity(event)) ? false : (seen.add(eventIdentity(event)), true)))
    .sort((left, right) => time(right) - time(left))
    .slice(0, cap);
  const seenAlerts = new Set<string>();
  const alerts = [...next.events, ...(previous?.alerts ?? []).filter((event) => !newest.has(eventIdentity(event)))]
    .filter((event) => isAlertKind(event.kind) && nowMs - time(event) <= windowMs)
    .filter((event) => (seenAlerts.has(eventIdentity(event)) ? false : (seenAlerts.add(eventIdentity(event)), true)))
    .sort((left, right) => time(right) - time(left));
  // the oldest moment the wire ever showed this page (P0-11): the bell can
  // only vouch for alerts since then, whatever its window says
  let observedFrom = previous?.observedFrom ?? null;
  for (const event of next.events) {
    const t = time(event);
    if (t !== Number.NEGATIVE_INFINITY && (observedFrom === null || t < Date.parse(observedFrom))) observedFrom = event.at;
  }
  return { cursor: next.cursor, events, alerts, observedFrom };
}

/**
 * The span the bell actually observed (P0-11): the window, clipped to the
 * moment the wire's first answer began. The server hands the newest 120
 * events, so a busy swarm's first answer may begin minutes ago, not an hour;
 * the bell then names those minutes instead of implying the hour. Null
 * until the wire has answered once.
 */
export function alertSpan(observedFrom: string | null, nowMs: number, windowMs = ALERT_WINDOW_MS): { seconds: number; clipped: boolean } | null {
  if (observedFrom === null) return null;
  const from = Date.parse(observedFrom);
  if (!Number.isFinite(from)) return null;
  const observed = Math.max(0, nowMs - from);
  return observed < windowMs ? { seconds: Math.round(observed / 1000), clipped: true } : { seconds: Math.round(windowMs / 1000), clipped: false };
}

/**
 * What the feed holds (P1-27): its row count and the span between its
 * oldest and newest rows, from the rows themselves. The span is null with
 * fewer than two datable rows; the header then prints the count alone and
 * never a fabricated "0 s".
 */
export function feedCoverage(events: Array<{ at: string }>): { rows: number; spanSeconds: number | null; oldestAt: string | null; newestAt: string | null } {
  let oldest: number | null = null;
  let newest: number | null = null;
  let oldestAt: string | null = null;
  let newestAt: string | null = null;
  for (const event of events) {
    const t = Date.parse(event.at);
    if (!Number.isFinite(t)) continue;
    if (oldest === null || t < oldest) { oldest = t; oldestAt = event.at; }
    if (newest === null || t > newest) { newest = t; newestAt = event.at; }
  }
  const spanSeconds = oldest !== null && newest !== null && oldestAt !== newestAt ? Math.round((newest - oldest) / 1000) : null;
  return { rows: events.length, spanSeconds, oldestAt, newestAt };
}

/**
 * How long a bee has been silent (P1-23): seconds since its last word on
 * the wire, and whether that silence outlasts one round. Cold only when a
 * round length is known; no last word yields null, never a fabricated age.
 */
export function beeSilence(latestAt: string | null | undefined, nowMs: number, roundSeconds: number | null): { seconds: number; cold: boolean } | null {
  if (!latestAt) return null;
  const t = Date.parse(latestAt);
  if (!Number.isFinite(t)) return null;
  const seconds = Math.max(0, Math.round((nowMs - t) / 1000));
  return { seconds, cold: roundSeconds !== null && roundSeconds > 0 && seconds > roundSeconds };
}
