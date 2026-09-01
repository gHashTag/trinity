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

console.log(
  "Queen cycle identity: canonical TrinityLogo centered inside three concentric orbit rings",
);
