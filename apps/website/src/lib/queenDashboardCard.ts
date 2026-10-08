// The dashboard's card, run: gHashTag/t27 specs/queen/dashboard.t27 compiled to
// wasm (public/t27/queen/dashboard.wasm, the same bytes the Queen's server runs
// for the drawer). It imports nothing; this file only loads it and passes
// numbers in and out, so why the bees are idle and how the board splits into
// lanes are the spec's own code.

import { IV_UNKNOWN, TONE_NONE } from "./queenDashboard.generated";

interface DashboardCardExports {
  free_lanes(capacity: number, active: number): number;
  idle_verdict(known: number, capacity: number, active: number, waiting: number, noBoundary: number, heldFiles: number, claimed: number): number;
  verdict_tone(verdict: number): number;
  lane_shown(rank: number): number;
}

let card: DashboardCardExports | null = null;

/** Resolves once the card is loaded; until then the strip says nothing and the board has no lanes. */
export const dashboardCardReady: Promise<void> =
  typeof window === "undefined"
    ? Promise.resolve()
    : fetch(`${import.meta.env.BASE_URL}t27/queen/dashboard.wasm`)
        .then((response) => (response.ok ? response.arrayBuffer() : Promise.reject(new Error(`dashboard.wasm: http ${response.status}`))))
        .then((bytes) => WebAssembly.instantiate(bytes, {}))
        .then(({ instance }) => {
          (instance.exports._initialize as (() => void) | undefined)?.();
          card = instance.exports as unknown as DashboardCardExports;
        });

export function dashboardCardLoaded(): boolean {
  return card !== null;
}

const u32 = (n: number) => (Number.isFinite(n) ? Math.max(0, Math.min(0xffffffff, Math.floor(n))) >>> 0 : 0);

export function dashFreeLanes(capacity: number, active: number): number {
  return card ? card.free_lanes(u32(capacity), u32(active)) : 0;
}

/** idle_verdict; with no card, or no round to read, the verdict is unknown. */
export function dashIdleVerdict(known: boolean, capacity: number, active: number, waiting: number, noBoundary: number, heldFiles: number, claimed: number): number {
  if (!card) return IV_UNKNOWN;
  return card.idle_verdict(known ? 1 : 0, u32(capacity), u32(active), u32(waiting), u32(noBoundary), u32(heldFiles), u32(claimed));
}

export function dashVerdictTone(verdict: number): number {
  return card ? card.verdict_tone(verdict & 0xff) : TONE_NONE;
}

export function dashLaneShown(rank: number): boolean {
  return card ? card.lane_shown(u32(rank)) !== 0 : false;
}
