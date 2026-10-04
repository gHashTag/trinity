import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("..", import.meta.url));
const queenPath = `${root}/src/pages/Queen.tsx`;
const cssPath = `${root}/src/pages/Queen.css`;
const queen = readFileSync(queenPath, "utf8");
const css = readFileSync(cssPath, "utf8");

assert.match(
  queen,
  /<div className="queen27-core-orbit" aria-hidden="true">[\s\S]*?<TrinityLogo withLabel=\{false\} height="72px" \/>[\s\S]*?<\/div>/,
  "the Queen cycle must render the canonical 27-petal TrinityLogo",
);
assert.doesNotMatch(
  queen,
  /QueenCycleGlyph/,
  "the simplified replacement glyph must not be wired into Queen",
);

const orbitMarkup = [
  ...queen.matchAll(/<span\s+data-role="orbit"\s+className="queen27-cycle-ring[^>]*\/>/g),
];
assert.equal(orbitMarkup.length, 3, "the cycle mark must contain three orbit rings");

assert.match(
  css,
  /\.queen27-cycle-ring\s*\{[\s\S]*?position:\s*absolute;[\s\S]*?border-radius:\s*50%;[\s\S]*?\}/,
  "every orbit ring must be an absolute circle inside the shared square",
);

assert.match(
  css,
  /\.queen27-cycle-brand\s*\{[\s\S]*?position:\s*absolute;[\s\S]*?inset:\s*0;[\s\S]*?place-items:\s*center;[\s\S]*?\}/,
  "the canonical logo must use the same full-square center as every ring",
);

// The original 27-petal mark is intentionally asymmetric: the centroid of its
// innermost black triangle is above the centre of the square viewBox. Keep the
// real logo, but align that optical core with the orbit centre. At 72 CSS px the
// 480-unit viewBox scale turns the 37.97-unit delta into 5.70 px.
const viewBoxCenterY = 300 + 440 / 2;
const coreCenterY = (474.893 + 474.865 + 496.337) / 3;
const opticalOffset = (viewBoxCenterY - coreCenterY) * (72 / 480);
assert.equal(opticalOffset.toFixed(1), "5.7");
assert.match(
  css,
  /--queen27-cycle-optical-y:\s*5\.7px;/,
  "the cycle must declare the geometry-derived optical offset",
);
assert.match(
  css,
  /\.queen27-cycle-brand svg\s*\{[\s\S]*?transform:\s*translateY\(var\(--queen27-cycle-optical-y\)\);[\s\S]*?\}/,
  "the original logo core must be translated onto the orbit centre",
);

console.log(
  "Queen cycle identity: canonical TrinityLogo optically centered inside three concentric orbit rings",
);
