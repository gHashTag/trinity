import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("..", import.meta.url));
const glyphPath = `${root}/src/components/QueenCycleGlyph.tsx`;
const queenPath = `${root}/src/pages/Queen.tsx`;
const glyph = readFileSync(glyphPath, "utf8");
const queen = readFileSync(queenPath, "utf8");

assert.match(glyph, /viewBox="0 0 240 240"/);
assert.match(glyph, /shapeRendering="geometricPrecision"/);

const circles = [...glyph.matchAll(/<circle\s+[^>]*data-role="orbit"[^>]*>/g)];
assert.equal(circles.length, 3, "the cycle mark must contain three orbit circles");

const attr = (tag, name) => {
  const match = tag.match(new RegExp(`${name}="([^"]+)"`));
  assert.ok(match, `missing ${name} on ${tag}`);
  return Number(match[1]);
};

for (const [match, expectedRadius] of circles.map((entry, index) => [entry[0], [118, 92, 58][index]])) {
  assert.equal(attr(match, "cx"), 120);
  assert.equal(attr(match, "cy"), 120);
  assert.equal(attr(match, "r"), expectedRadius);
}

const primary = glyph.match(/<polygon\s+[^>]*data-role="primary-triangle"[^>]*>/)?.[0];
assert.ok(primary, "the cycle mark must contain one primary triangle");
const points = primary
  .match(/points="([^"]+)"/)?.[1]
  .trim()
  .split(/\s+/)
  .map((point) => point.split(",").map(Number));
assert.equal(points?.length, 3);

const [a, b, c] = points;
const centroid = [
  (a[0] + b[0] + c[0]) / 3,
  (a[1] + b[1] + c[1]) / 3,
];
assert.ok(Math.abs(centroid[0] - 120) < 0.01);
assert.ok(Math.abs(centroid[1] - 120) < 0.01);

const distance = (left, right) => Math.hypot(left[0] - right[0], left[1] - right[1]);
const sides = [distance(a, b), distance(b, c), distance(c, a)];
assert.ok(Math.max(...sides) - Math.min(...sides) < 0.01, "the primary triangle must be equilateral");

assert.match(queen, /import \{ QueenCycleGlyph \} from "\.\.\/components\/QueenCycleGlyph";/);
assert.match(queen, /<QueenCycleGlyph \/>/);

console.log("Queen cycle geometry: 3 concentric circles, centered equilateral triangle, live component wiring");
