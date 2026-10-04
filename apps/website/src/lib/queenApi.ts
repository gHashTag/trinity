/**
 * The supervisor's address, in one place.
 *
 * This literal lived inside Queen.tsx and nothing else could reach it, so a
 * second surface wanting the same server had to copy the string — and a copied
 * address is one that disagrees with itself the first time a deployment moves.
 * VITE_QUEEN_API overrides it for a local server.
 */
const DEFAULT_QUEEN_API = "https://trios-agent-server-production.up.railway.app";

export const QUEEN_API = (
  (import.meta.env.VITE_QUEEN_API as string | undefined) ?? DEFAULT_QUEEN_API
).replace(/\/+$/, "");

/**
 * An issue whose body states a boundary the way the Queen requires. Two
 * surfaces point a reader at it — the HUD's idle line and the homepage's
 * DIRECT card — and one exemplar that has moved in one of them is worse than
 * none, so it is named once.
 */
export const BOUNDARY_EXAMPLE_ISSUE = "https://github.com/gHashTag/t27/issues/3587";
