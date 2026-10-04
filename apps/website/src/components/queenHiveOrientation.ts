// Facing wall after the user's180-degree turn: local(x,height,z) -> (-x,z,height).
// The camera stays at +Z. SVG y maps to local -z, so the original mark points down.
export const HIVE_WALL_ROTATION = { x: -Math.PI / 2, y: Math.PI, z: 0 } as const;
export function hiveWallToWorld(x: number, z: number) { return { x: -x, y: z }; }
export function hiveWorldToWall(x: number, y: number, driftY = 0) { return { x: -x, z: y - driftY }; }
