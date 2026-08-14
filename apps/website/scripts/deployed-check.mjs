// Is what t27.ai serves the same thing this tree builds?
//
// anomaly-register A51: four PRs merged, every check green, and the live site
// changed nothing. The SPA deploys from a second repository that holds build
// output only, and nothing copies a build into it. The site kept serving
// "First chip with native SU(3) Unitary Core" for a week after the tree that
// produces it stopped saying that.
//
// A51 concluded no test in the source repo could see this. That was wrong by
// one assumption: a test that FETCHES THE LIVE SITE can. This is that test.
//
//   npm run check:deployed
//
// It compares what the deployed index.html loads against what dist/index.html
// loads. Vite hashes bundle names by content, so equal names mean equal
// bundles and a different name means the deploy is behind -- or ahead, which
// is worth knowing too.
//
// What it cannot tell you: WHICH direction, or whether the difference matters.
// A whitespace change moves the hash. So this warns; it does not fail a build.
// A gate that blocks a merge because someone has not deployed yet inverts the
// order of operations.
import { readFileSync, existsSync } from 'node:fs';

const SITE = process.env.DEPLOY_URL ?? 'https://t27.ai/';
const entryOf = (html) => (html.match(/assets\/(index-[\w-]+\.js)/) ?? [])[1];

if (!existsSync('dist/index.html')) {
  console.log('  no dist/ — run `npx vite build` first (nothing to compare)');
  process.exit(0);
}
const local = entryOf(readFileSync('dist/index.html', 'utf8'));
if (!local) {
  console.error('  no entry bundle in dist/index.html. That is a build problem, not a deploy one.');
  process.exit(1);
}

let live;
try {
  const res = await fetch(SITE, { headers: { 'User-Agent': 'deployed-check' } });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  live = entryOf(await res.text());
} catch (e) {
  // Offline, or the site is down. Neither is a defect in this change, and a
  // check that fails when the network does gets muted.
  console.log(`  could not reach ${SITE} (${e.message}) — skipping`);
  process.exit(0);
}

if (!live) {
  console.error(`  ${SITE} serves no index-*.js bundle. Either it is not this app, or it is broken.`);
  process.exit(1);
}
if (live === local) {
  console.log(`  deployed: ${live} — the live site is this build`);
  process.exit(0);
}
console.log(`\n  the live site is NOT this build:\n`);
console.log(`    ${SITE.padEnd(28)} ${live}`);
console.log(`    dist/index.html              ${local}\n`);
console.log('  Merging does not deploy this site. The build output lives in a second');
console.log('  repository and is copied there by hand — see anomaly-register A51.');
