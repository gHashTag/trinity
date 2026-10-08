// The event card, run: gHashTag/t27 specs/queen/events.t27 compiled to wasm
// (public/t27/queen/events.wasm, the same bytes the Queen's server runs). It
// imports nothing; this file only loads it and passes numbers in and out, so
// the board reads the event bus with the spec's own code, not a copy of it.
// A cursor is a u64 in the card, so it crosses as a BigInt.

interface EventsCardExports {
  delta_action(cursor: bigint, seq: bigint): number;
  refresh_action(changedTasks: number): number;
  board_action(kind: number): number;
}

let card: EventsCardExports | null = null;

/** Resolves once the card is loaded; the board follows the bus only after it. */
export const eventsCardReady: Promise<void> =
  typeof window === "undefined"
    ? Promise.resolve()
    : fetch(`${import.meta.env.BASE_URL}t27/queen/events.wasm`)
        .then((response) => (response.ok ? response.arrayBuffer() : Promise.reject(new Error(`events.wasm: http ${response.status}`))))
        .then((bytes) => WebAssembly.instantiate(bytes, {}))
        .then(({ instance }) => {
          (instance.exports._initialize as (() => void) | undefined)?.();
          card = instance.exports as unknown as EventsCardExports;
        });

export function eventsCardLoaded(): boolean {
  return card !== null;
}

/** For a test: the card from bytes already in hand. */
export async function loadEventsCardFrom(bytes: BufferSource): Promise<void> {
  const { instance } = await WebAssembly.instantiate(bytes, {});
  (instance.exports._initialize as (() => void) | undefined)?.();
  card = instance.exports as unknown as EventsCardExports;
}

const loaded = (): EventsCardExports => {
  if (!card) throw new Error("the event card is not loaded");
  return card;
};
const u64 = (n: number): bigint => BigInt(Number.isSafeInteger(n) && n > 0 ? n : 0);

/** delta_action, from the card: 0 skip, 1 apply, 2 resync. */
export function cardDeltaAction(cursor: number, seq: number): number {
  return loaded().delta_action(u64(cursor), u64(seq));
}

/** refresh_action, from the card: 0 nothing, 1 the named tasks, 2 a whole snapshot. */
export function cardRefreshAction(changedTasks: number): number {
  return loaded().refresh_action(Math.max(0, Math.min(0xffffffff, Math.floor(changedTasks))) >>> 0);
}

/** board_action, from the card: 0 nothing, 1 refresh the task, 2 touch its bee. */
export function cardBoardAction(kind: number): number {
  if (!Number.isInteger(kind) || kind < 0 || kind > 255) return 0;
  return loaded().board_action(kind);
}
