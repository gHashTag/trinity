// The task card, run: gHashTag/t27 specs/queen/tasks.t27 compiled to wasm
// (public/t27/queen/tasks.wasm, the same bytes the Queen's server runs). It
// imports nothing; this file only loads it and passes numbers in and out, so
// the board and the game decide with the spec's own code, not a copy of it.

interface TasksCardExports {
  task_matches(kindMask: number, stateMask: number, kind: number, state: number): number;
  bee_state(claimed: number, secondsSince: number): number;
}

let card: TasksCardExports | null = null;

/** Resolves once the card is loaded; the task feed waits for it. */
export const cardReady: Promise<void> =
  typeof window === "undefined"
    ? Promise.resolve()
    : fetch(`${import.meta.env.BASE_URL}t27/queen/tasks.wasm`)
        .then((response) => (response.ok ? response.arrayBuffer() : Promise.reject(new Error(`tasks.wasm: http ${response.status}`))))
        .then((bytes) => WebAssembly.instantiate(bytes, {}))
        .then(({ instance }) => {
          (instance.exports._initialize as (() => void) | undefined)?.();
          card = instance.exports as unknown as TasksCardExports;
        });

export function cardLoaded(): boolean {
  return card !== null;
}

const u32 = (n: number) => Math.max(0, Math.min(0xffffffff, Math.floor(n))) >>> 0;

/** task_matches, from the card. An index the card does not know matches nothing. */
export function cardTaskMatches(kindMask: number, stateMask: number, kind: number, state: number): boolean {
  if (!card) return false;
  if (!Number.isInteger(kind) || !Number.isInteger(state) || kind < 0 || state < 0 || kind > 255 || state > 255) return false;
  return card.task_matches(u32(kindMask), u32(stateMask), kind, state) !== 0;
}

/** bee_state, from the card: 0 queued, 1 working, 2 quiet. */
export function cardBeeState(claimed: boolean, secondsSince: number): number {
  if (!card) throw new Error("the task card is not loaded");
  return card.bee_state(claimed ? 1 : 0, u32(secondsSince));
}
