import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import * as hud from "../src/components/queenHud.ts";

let checks = 0;
const failures = [];
function check(label, run) {
  checks++;
  try { run(); } catch (error) { failures.push(`${label}: ${error.message}`); }
}
const cover = hud.hiveCoverOf;
for (const path of ["rings/t27", "rings/t27-compiler", "specs", "specs/auth", "tests/t27/parser"]) {
  check(`no yellow inferred from ${path}`, () => assert.notEqual(cover(path, new Set()), "t27"));
}
check("basename is not a claim on another path", () => assert.notEqual(cover("other/auth", new Set(["auth"])), "t27"));
check("punctuation is identity", () => assert.notEqual(cover("a/b-c", new Set(["abc"])), "t27"));
check("exact path is a claim", () => assert.equal(cover("agent-server/auth", new Set(["agent-server/auth"])), "t27"));
check("unknown corpus is not manual code", () => assert.equal(cover("rings/t27", null), "unknown"));
check("empty cell awaits a boundary", () => assert.equal(cover(null, null), "awaiting"));
check("known corpus without a claim is migration debt", () => assert.equal(cover("manual", new Set()), "manual"));

const manifest = {
  coverageSchemaVersion: 1,
  repos: [{ repo: "trios", commit: "abcdef1" }, { repo: "trinity", commit: "abcdef2" }],
  specs: [
    { repo: "trios", module: "DisplayLabel", modulePath: "agent-server/auth", name: "OtherModule", path: "trios/specs/auth.t27" },
    { repo: "trinity", modulePath: "foreign", path: "trinity/specs/foreign.t27" },
  ],
};
const build = hud.hiveCoverageFromManifest;
check("manifest parsing is a testable production function", () => assert.equal(typeof build, "function"));
if (build) {
  check("only exact module claims from the displayed repository", () => assert.deepEqual([...build(manifest, "gHashTag/trios")], ["agent-server/auth"]));
  check("repository changes do not retain old claims", () => assert.deepEqual([...build(manifest, "gHashTag/trinity")], ["foreign"]));
  for (const repo of [null, 17, "gHashTag/missing", "another-owner/trios"]) {
    check(`unknown repository ${repo}`, () => assert.equal(build(manifest, repo), null));
  }
  for (const bad of [null, {}, { repos: manifest.repos }, { repos: manifest.repos, specs: [null] }]) {
    check(`invalid manifest ${JSON.stringify(bad)}`, () => assert.equal(build(bad, "gHashTag/trios"), null));
  }
  check("known empty corpus is distinct from unknown", () => assert.equal(build({ ...manifest, specs: [] }, "gHashTag/trios").size, 0));
  check("legacy module labels are not explicit path claims", () => {
    assert.equal(build({ repos: manifest.repos, specs: [{ repo: "trios", module: "auth", path: "trios/specs/unrelated.t27" }] }, "gHashTag/trios"), null);
    assert.equal(cover("DisplayLabel", build(manifest, "gHashTag/trios")), "manual");
  });
  check("primary t27 corpus has unprefixed source paths", () => {
    const primary = { coverageSchemaVersion: 1, repos: [{ repo: "t27", commit: "abcdef1" }], specs: [{ repo: "t27", modulePath: "compiler/auth", path: "specs/auth.t27" }] };
    assert.deepEqual([...build(primary, "gHashTag/t27")], ["compiler/auth"]);
  });
  check("versioned claims cannot omit the path mapping", () => assert.equal(build({ ...manifest, specs: [{ repo: "trios", module: "auth", path: "trios/specs/auth.t27" }] }, "gHashTag/trios"), null));
  for (const path of ["trios/../trinity/specs/foreign.t27", "trios//auth.t27", "trinity/specs/auth.t27", "trios/notes.md"]) {
    check(`invalid claim source ${path} is unknown`, () => assert.equal(build({ ...manifest, specs: [{ repo: "trios", modulePath: "auth", path }] }, "gHashTag/trios"), null));
  }
  check("unversioned corpus remains unknown", () => assert.equal(build({ ...manifest, repos: [{ repo: "trios" }] }, "gHashTag/trios"), null));
  check("case and traversal cannot alias another module", () => {
    const paths = ["../auth", "agent//auth", "/agent/auth", "agent/./auth", "agent/../auth", "agent\\auth"];
    for (const modulePath of paths) assert.equal(build({ ...manifest, specs: [{ repo: "trios", modulePath, path: "trios/specs/x.t27" }] }, "gHashTag/trios"), null);
    assert.equal(cover("Agent-Server/auth", build(manifest, "gHashTag/trios")), "manual");
  });
  check("display name does not claim a module", () => assert.equal(cover("OtherModule", build(manifest, "gHashTag/trios")), "manual"));
  const actual = JSON.parse(readFileSync(new URL("../public/t27/manifest.json", import.meta.url), "utf8"));
  const modules = JSON.parse(readFileSync(new URL("../public/queen/modules.json", import.meta.url), "utf8"));
  check("current snapshot has no corpus and cannot claim yellow", () => {
    assert.equal(build(actual, modules.repo), null);
    assert.ok(modules.modules.every(m => cover(m.path, build(actual, modules.repo)) === "unknown"));
  });
}
if (failures.length) { console.error(failures.join("\n")); console.error(`Hive coverage: FAIL (${failures.length}/${checks})`); process.exit(1); }
console.log(`Hive coverage: PASS (${checks} checks)`);
