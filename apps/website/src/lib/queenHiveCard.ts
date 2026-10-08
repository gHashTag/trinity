// The game's card, run: gHashTag/t27 specs/queen/hive.t27 compiled to wasm
// (public/t27/queen/hive.wasm). It imports nothing; this file only loads it and
// passes numbers in and out, so where a ship flies, how it leaves, what an event
// does to a cell and when the map may grow are the spec's own code.

import { FX_NONE, SM_PARK } from "./queenHive.generated";

interface HiveCardExports {
  ship_mode(queued: number, working: number, cell: number, departing: number): number;
  ship_kept(msSinceLeft: number): number;
  ship_alpha(departing: number, msSinceLeft: number): number;
  cell_effect(kind: number, accepted: number): number;
  flash_alpha(msSince: number): number;
  cells_due(pending: number, placedBefore: number, secondsSinceBatch: number): number;
}

let card: HiveCardExports | null = null;

/** Resolves once the card is loaded; until then the game draws no live bee. */
export const hiveCardReady: Promise<void> =
  typeof window === "undefined"
    ? Promise.resolve()
    : fetch(`${import.meta.env.BASE_URL}t27/queen/hive.wasm`)
        .then((response) => (response.ok ? response.arrayBuffer() : Promise.reject(new Error(`hive.wasm: http ${response.status}`))))
        .then((bytes) => WebAssembly.instantiate(bytes, {}))
        .then(({ instance }) => {
          (instance.exports._initialize as (() => void) | undefined)?.();
          card = instance.exports as unknown as HiveCardExports;
        });

export function hiveCardLoaded(): boolean {
  return card !== null;
}

const u32 = (n: number) => (Number.isFinite(n) ? Math.max(0, Math.min(0xffffffff, Math.floor(n))) >>> 0 : 0xffffffff);
const flag = (b: boolean) => (b ? 1 : 0);

/** ship_mode; a ship with no card yet is parked, which is where every ship starts. */
export function hiveShipMode(queued: boolean, working: boolean, cell: number, departing: boolean): number {
  return card ? card.ship_mode(flag(queued), flag(working), cell & 0xff, flag(departing)) : SM_PARK;
}

export function hiveShipKept(msSinceLeft: number): boolean {
  return card ? card.ship_kept(u32(msSinceLeft)) !== 0 : false;
}

/** ship_alpha, in thousandths. */
export function hiveShipAlpha(departing: boolean, msSinceLeft: number): number {
  return card ? card.ship_alpha(flag(departing), u32(msSinceLeft)) : 1000;
}

export function hiveCellEffect(kind: number, accepted: boolean): number {
  if (!card || !Number.isInteger(kind) || kind < 0 || kind > 255) return FX_NONE;
  return card.cell_effect(kind, flag(accepted));
}

/** flash_alpha, in thousandths. */
export function hiveFlashAlpha(msSince: number): number {
  return card ? card.flash_alpha(u32(msSince)) : 0;
}

/** cells_due; nothing is placed before the card says so (the map waits for hiveCardReady). */
export function hiveCellsDue(pending: number, placedBefore: boolean, secondsSinceBatch: number): boolean {
  return card ? card.cells_due(u32(pending), flag(placedBefore), u32(secondsSinceBatch)) !== 0 : false;
}
