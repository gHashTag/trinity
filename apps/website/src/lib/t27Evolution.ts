/**
 * The TECH TREE's subject: how the .t27 language got from a seed compiler to
 * the backends and repositories it has now -- derived, not asserted. (This
 * sentence used to say "five backends". It was a literal in a file whose whole
 * claim is that it holds none, and it went stale the day a sixth landed.)
 *
 * The tree used to draw whatever /queen/public-research returned. That endpoint
 * is the supervisor's, it describes the supervisor's own research, and when the
 * container is down (HTTP 502 on 2026-09-20, then no answer at all) the tab drew
 * RESEARCH GRAPH OFFLINE and nothing else. Meanwhile the one thing the page is
 * about -- the language -- had a measured, dated index sitting in the same
 * bundle: public/t27/manifest.json, written from gHashTag/t27 at a named commit,
 * with per-spec construct counts, per-spec generated-output sizes for every
 * backend, and the type and round-trip results for all of them.
 *
 * So every node below rests on a count this function read out of that index.
 * Nothing here is a literal about the corpus: change the manifest and the
 * numbers, the states and the summary all move. If the index is missing or the
 * shape is not the one described here, this returns null and the tab says so,
 * rather than drawing a tree of confident nothing.
 *
 * The node STATE is derived the same way for every node, and it is the only
 * judgement this file makes:
 *   researched  -- the step is measured here, with no recorded failure or warning
 *   researching -- the step is measured here, and the index records failures or
 *                  warnings against it
 *   available   -- every prerequisite is measured, and this index carries no
 *                  measurement of this step at all
 *   locked      -- a prerequisite is not measured here, so nothing in this index
 *                  says this step is reachable yet
 *
 * A prerequisite locks what follows it by being UNMEASURED, not by being
 * imperfect. The first draft of this rule required a prerequisite to be
 * `researched`, and drew gen-rust as locked underneath its own evidence that
 * 1 405 specs and 3.6 MB of Rust had come out of it -- because the type check
 * above it carries 200 warnings. A step that demonstrably ran is not blocked by
 * an imperfect step above it; it is running with a known imperfection above it,
 * which is what `researching` on that upstream node already says.
 */

export type T27EvolutionState =
  | "researched"
  | "researching"
  | "available"
  | "locked";

export interface T27EvolutionNode {
  id: string;
  label: string;
  layer: string;
  maturity: "shipped" | "partial" | "blocked" | "planned" | "unknown";
  state: T27EvolutionState;
  evidence: string;
  note?: string;
  blockedBy?: string;
  prerequisites: string[];
  unlocks: string[];
}

export interface T27EvolutionGraph {
  nodes: T27EvolutionNode[];
  edges: Array<{ from: string; to: string }>;
  layers: string[];
  summary: {
    total: number;
    researched: number;
    researching: number;
    available: number;
    locked: number;
    percentage: number;
  };
  /** The corpus this graph was read out of, for the caller to print. */
  source: { repo: string; commit: string; specs: number };
}

/** The manifest fields this derivation reads. Everything else is ignored. */
interface CorpusSpec {
  path?: unknown;
  category?: unknown;
  repo?: unknown;
  tags?: unknown;
  kinds?: unknown;
  outBytes?: unknown;
  failedBackends?: unknown;
}

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

const int = (value: unknown): number =>
  typeof value === "number" && Number.isFinite(value) ? Math.trunc(value) : 0;

const str = (value: unknown): string => (typeof value === "string" ? value : "");

/**
 * A count formatted the way both languages read it: 1 407, not 1,407.
 *
 * Grouped by hand rather than by toLocaleString, because the gate that checks
 * these numbers runs in Node and the page runs in a browser, and two ICU builds
 * disagreeing about a separator would fail a gate about arithmetic over a space.
 * The separator is a no-break space, so a count never wraps across two lines.
 */
const n = (value: number): string =>
  String(value).replace(/\B(?=(\d{3})+(?!\d))/g, "\u00a0");

interface Counted {
  /** How many AST nodes of this kind the whole corpus contains. */
  total: number;
  /** How many specs contain at least one. */
  specs: number;
}

function countKind(specs: CorpusSpec[], ...kinds: string[]): Counted {
  let total = 0;
  let touched = 0;
  for (const spec of specs) {
    if (!isRecord(spec.kinds)) continue;
    let here = 0;
    for (const kind of kinds) here += int(spec.kinds[kind]);
    if (here > 0) {
      total += here;
      touched += 1;
    }
  }
  return { total, specs: touched };
}

function countTag(specs: CorpusSpec[], tag: string): number {
  let count = 0;
  for (const spec of specs) {
    if (Array.isArray(spec.tags) && spec.tags.includes(tag)) count += 1;
  }
  return count;
}

interface BackendCount {
  /** Specs whose generated output for this backend has a non-zero size. */
  generated: number;
  /** Specs the index records as having failed this backend. */
  failed: number;
  /** Total bytes generated for this backend across the corpus. */
  bytes: number;
}

function countBackend(specs: CorpusSpec[], backend: string): BackendCount {
  let generated = 0;
  let failed = 0;
  let bytes = 0;
  for (const spec of specs) {
    if (isRecord(spec.outBytes)) {
      const size = int(spec.outBytes[backend]);
      if (size > 0) {
        generated += 1;
        bytes += size;
      }
    }
    if (Array.isArray(spec.failedBackends) && spec.failedBackends.includes(backend)) {
      failed += 1;
    }
  }
  return { generated, failed, bytes };
}

/** Specs per repository, biggest first. The index names the repo on each spec. */
function countRepos(specs: CorpusSpec[]): Array<{ repo: string; specs: number }> {
  const byRepo = new Map<string, number>();
  for (const spec of specs) {
    const repo = str(spec.repo) || "t27";
    byRepo.set(repo, (byRepo.get(repo) ?? 0) + 1);
  }
  return [...byRepo.entries()]
    .map(([repo, count]) => ({ repo, specs: count }))
    .sort((a, b) => b.specs - a.specs || a.repo.localeCompare(b.repo));
}

/** Specs whose category path starts with this prefix. */
function countCategory(specs: CorpusSpec[], prefix: string): number {
  let count = 0;
  for (const spec of specs) {
    if (str(spec.category).startsWith(prefix)) count += 1;
  }
  return count;
}

/**
 * The evolution of .t27, read out of the corpus index.
 *
 * `lang` decides the language of the labels and the evidence, because the
 * caller hands both straight to the panel and a graph that answers in one
 * language on a page rendered in the other is the defect publicResearchText
 * exists to catch.
 */
export function deriveT27Evolution(
  manifest: unknown,
  lang: string,
): T27EvolutionGraph | null {
  if (!isRecord(manifest)) return null;
  const rawSpecs = manifest.specs;
  if (!Array.isArray(rawSpecs) || rawSpecs.length === 0) return null;
  const specs = rawSpecs.filter(isRecord) as CorpusSpec[];
  if (specs.length === 0) return null;

  const ru = lang === "ru";
  const from = isRecord(manifest.generatedFrom) ? manifest.generatedFrom : {};
  const health = isRecord(manifest.health) ? manifest.health : {};
  const totals = isRecord(manifest.totals) ? manifest.totals : {};

  const specCount = int(manifest.specCount) || specs.length;
  const totalLines = int(manifest.totalLines);
  const wasmBytes = int(manifest.wasmBytes);
  const repo = str(from.repo) || "gHashTag/t27";
  const commit = str(from.shortCommit) || str(from.commit).slice(0, 9);
  const checkedOnDefault = int(from.t27SpecsChecked);
  const bootstrapSpecs = countCategory(specs, "bootstrap/");

  const healthOk = int(health.ok);
  const healthWarn = int(health.warn);
  const healthFail = int(health.fail);
  const typeErrors = int(totals.tcAffected);
  const lossy = int(totals.lossAffected);
  const astNodes = int(totals.nodes);
  const tokens = int(totals.tokens);

  const modules = countKind(specs, "Module");
  const imports = countTag(specs, "has/imports");
  const functions = countKind(specs, "FnDecl");
  const types = countKind(specs, "StructDecl", "EnumVariant");
  const tests = countKind(specs, "TestBlock");
  const invariants = countKind(specs, "InvariantBlock");
  const benches = countTag(specs, "has/benches");

  // The Russian labels keep the command name and put a Russian word in front of
  // it. They have to: publicResearchText replaces any label whose script does
  // not match the page, so a bare "gen-rust" on the Russian page would be drawn
  // as "Технология gen-rust" and the backend's actual name would be lost.
  // `after` is the node this one hangs from. Two of them do not hang from the
  // typechecker, and neither edge is a drawing decision: the HIR path reaches
  // Verilog through gen-verilog, and gen-ts is built ON gen-js -- TypeScript's
  // syntax for a value IS JavaScript's, so upstream `codegen_ts.rs` calls
  // `codegen_js.rs` for every literal, escape and name it prints. The edge in
  // this graph is the call in the compiler.
  const backends = [
    { id: "gen-rust", key: "rust", en: "gen-rust", ru: "бэкенд gen-rust", after: "typecheck" },
    { id: "gen-zig", key: "zig", en: "gen (Zig)", ru: "бэкенд gen (Zig)", after: "typecheck" },
    { id: "gen-c", key: "c", en: "gen-c", ru: "бэкенд gen-c", after: "typecheck" },
    { id: "gen-verilog", key: "verilog", en: "gen-verilog", ru: "бэкенд gen-verilog", after: "typecheck" },
    {
      id: "gen-verilog-hir",
      key: "verilog_hir",
      en: "verilog HIR",
      ru: "бэкенд verilog HIR",
      after: "gen-verilog",
    },
    { id: "gen-js", key: "js", en: "gen-js", ru: "бэкенд gen-js", after: "typecheck" },
    { id: "gen-ts", key: "ts", en: "gen-ts", ru: "бэкенд gen-ts", after: "gen-js" },
  ].map((backend) => ({ ...backend, count: countBackend(specs, backend.key) }));

  const repos = countRepos(specs);
  const adopters = repos.slice(0, 5);
  const restRepos = repos.slice(5);
  const restSpecs = restRepos.reduce((sum, entry) => sum + entry.specs, 0);

  const fpgaSpecs = countCategory(specs, "specs/fpga");
  const iglaSpecs = countCategory(specs, "specs/igla");

  // Every node, as a description of what it rests on. `measured` is false only
  // when this index carries no reading of the step at all -- which is how the
  // silicon node stays honest: the corpus can say how many specs describe an
  // FPGA, and cannot say what a board did.
  interface Draft {
    id: string;
    layer: string;
    label: string;
    evidence: string;
    note?: string;
    prerequisites: string[];
    measured: boolean;
    failures: number;
    warnings: number;
  }

  const drafts: Draft[] = [
    {
      id: "t27c",
      layer: "seed",
      label: ru ? "t27c, компилятор-семя" : "t27c, the seed compiler",
      evidence: ru
        ? `${repo}@${commit}: ${n(bootstrapSpecs)} спек под bootstrap/, а сам компилятор, собранный в WebAssembly, весит ${n(wasmBytes)} байт и отдаётся этой же страницей по /t27/t27_compiler.wasm.`
        : `${repo}@${commit}: ${n(bootstrapSpecs)} specs under bootstrap/, and the compiler itself, built to WebAssembly, is ${n(wasmBytes)} bytes and is served by this same page at /t27/t27_compiler.wasm.`,
      note: ru
        ? "Единственное исключение из правила «всё пишется на .t27»: семя написано на Rust руками, и в этом его смысл."
        : "The one exception to the rule that everything is written in .t27: the seed is hand-written Rust, and that is the point of it.",
      prerequisites: [],
      measured: true,
      failures: 0,
      warnings: 0,
    },
    {
      id: "modules",
      layer: "language",
      label: ru ? "Модули и импорты" : "Modules and imports",
      evidence: ru
        ? `${n(modules.total)} объявлений module в ${n(modules.specs)} спеках; ${n(imports)} спек импортируют другую.`
        : `${n(modules.total)} module declarations across ${n(modules.specs)} specs; ${n(imports)} specs import another.`,
      prerequisites: ["t27c"],
      measured: modules.total > 0,
      failures: 0,
      warnings: 0,
    },
    {
      id: "functions",
      layer: "language",
      label: ru ? "Функции" : "Functions",
      evidence: ru
        ? `${n(functions.total)} объявлений fn в ${n(functions.specs)} спеках из ${n(specCount)}.`
        : `${n(functions.total)} fn declarations across ${n(functions.specs)} of ${n(specCount)} specs.`,
      prerequisites: ["t27c"],
      measured: functions.total > 0,
      failures: 0,
      warnings: 0,
    },
    {
      id: "types",
      layer: "language",
      label: ru ? "Структуры и перечисления" : "Structs and enums",
      evidence: ru
        ? `${n(types.total)} объявлений struct и вариантов enum в ${n(types.specs)} спеках.`
        : `${n(types.total)} struct declarations and enum variants across ${n(types.specs)} specs.`,
      prerequisites: ["t27c"],
      measured: types.total > 0,
      failures: 0,
      warnings: 0,
    },
    {
      id: "tests",
      layer: "language",
      label: ru ? "Тесты в самой спеке" : "Tests inside the spec",
      evidence: ru
        ? `${n(tests.total)} блоков test в ${n(tests.specs)} спеках — тест живёт в том же файле, что и то, что он проверяет.`
        : `${n(tests.total)} test blocks in ${n(tests.specs)} specs -- the test lives in the same file as the thing it checks.`,
      prerequisites: ["functions"],
      measured: tests.total > 0,
      failures: 0,
      warnings: 0,
    },
    {
      id: "invariants",
      layer: "language",
      label: ru ? "Инварианты" : "Invariants",
      evidence: ru
        ? `${n(invariants.total)} блоков invariant в ${n(invariants.specs)} спеках, и ${n(benches)} спек несут бенчмарк.`
        : `${n(invariants.total)} invariant blocks in ${n(invariants.specs)} specs, and ${n(benches)} specs carry a bench.`,
      prerequisites: ["functions"],
      measured: invariants.total > 0,
      failures: 0,
      warnings: 0,
    },
    {
      id: "typecheck",
      layer: "check",
      label: ru ? "Проверка типов" : "Type checking",
      evidence: ru
        ? `${n(specCount - typeErrors)} спек из ${n(specCount)} проходят проверку типов; ${n(typeErrors)} несут ошибки типов.`
        : `${n(specCount - typeErrors)} of ${n(specCount)} specs pass the type check; ${n(typeErrors)} carry type errors.`,
      prerequisites: ["types", "functions"],
      measured: true,
      failures: 0,
      warnings: typeErrors,
    },
    {
      id: "roundtrip",
      layer: "check",
      label: ru ? "Разбор без потерь" : "Lossless parse",
      evidence: ru
        ? `${n(tokens)} токенов и ${n(astNodes)} узлов AST на ${n(totalLines)} строках; ${n(lossy)} спек не проходят обратный разбор без потерь.`
        : `${n(tokens)} tokens and ${n(astNodes)} AST nodes over ${n(totalLines)} lines; ${n(lossy)} specs do not round-trip without loss.`,
      prerequisites: ["modules"],
      measured: true,
      failures: 0,
      warnings: lossy,
    },
    {
      id: "health",
      layer: "check",
      label: ru ? "Здоровье корпуса" : "Corpus health",
      evidence: ru
        ? `${n(healthOk)} ok, ${n(healthWarn)} warn, ${n(healthFail)} fail из ${n(specCount)}; ${n(checkedOnDefault)} спек проверены на ветке по умолчанию.`
        : `${n(healthOk)} ok, ${n(healthWarn)} warn, ${n(healthFail)} fail of ${n(specCount)}; ${n(checkedOnDefault)} specs checked on the default ref.`,
      prerequisites: ["tests", "invariants"],
      measured: true,
      failures: healthFail,
      warnings: healthWarn,
    },
    ...backends.map((backend) => ({
      id: backend.id,
      layer: "backend",
      label: ru ? backend.ru : backend.en,
      evidence: ru
        ? `${n(backend.count.generated)} спек из ${n(specCount)} порождают вывод для этого бэкенда, всего ${n(backend.count.bytes)} байт; индекс записывает ${n(backend.count.failed)} отказов.`
        : `${n(backend.count.generated)} of ${n(specCount)} specs generate output for this backend, ${n(backend.count.bytes)} bytes in all; the index records ${n(backend.count.failed)} failures.`,
      prerequisites: [backend.after],
      measured: backend.count.generated > 0,
      failures: backend.count.failed,
      warnings: 0,
    })),
    ...adopters.map((entry) => ({
      id: `repo-${entry.repo}`,
      layer: "adoption",
      label: ru ? `репозиторий ${entry.repo}` : entry.repo,
      evidence: ru
        ? `${n(entry.specs)} спек этого репозитория стоят в общем индексе корпуса.`
        : `${n(entry.specs)} specs from this repository stand in the shared corpus index.`,
      prerequisites: ["gen-rust"],
      measured: entry.specs > 0,
      failures: 0,
      warnings: 0,
    })),
    {
      id: "silicon",
      layer: "silicon",
      label: ru ? "Путь к кремнию" : "The silicon path",
      evidence: ru
        ? `${n(fpgaSpecs)} спек в specs/fpga и ${n(iglaSpecs)} в specs/igla порождают Verilog. Что именно прошито в плату, этот индекс не знает и здесь не утверждается.`
        : `${n(fpgaSpecs)} specs under specs/fpga and ${n(iglaSpecs)} under specs/igla generate Verilog. What a board was actually programmed with is not in this index and is not claimed here.`,
      note: ru
        ? "Аппаратные результаты живут в t27/fpga/HARDWARE_SSOT.md и принадлежат другому агенту; второй реестр здесь был бы вторым домом для правды."
        : "Hardware results live in t27/fpga/HARDWARE_SSOT.md and belong to another agent; a second register here would be a second home for the truth.",
      prerequisites: ["gen-verilog"],
      measured: false,
      failures: 0,
      warnings: 0,
    },
  ];

  if (restSpecs > 0) {
    drafts.push({
      id: "repo-rest",
      layer: "adoption",
      label: ru
        ? `ещё ${n(restRepos.length)} репозиториев`
        : `${n(restRepos.length)} more repositories`,
      evidence: ru
        ? `${n(restSpecs)} спек из ${n(restRepos.length)} остальных репозиториев: ${restRepos.map((entry) => entry.repo).join(", ")}.`
        : `${n(restSpecs)} specs from the remaining ${n(restRepos.length)} repositories: ${restRepos.map((entry) => entry.repo).join(", ")}.`,
      prerequisites: ["gen-rust"],
      measured: true,
      failures: 0,
      warnings: 0,
    });
  }

  // State, in one pass over the drafts. A prerequisite is looked up by whether
  // this index measures it at all, which is a property of the draft rather than
  // of the order the drafts are listed in, so the pass does not depend on the
  // listing being topological.
  const measured = new Map<string, boolean>(
    drafts.map((draft) => [draft.id, draft.measured]),
  );
  const ownState = (draft: Draft): T27EvolutionState => {
    const blocked = draft.prerequisites.some((id) => measured.get(id) !== true);
    if (blocked) return "locked";
    if (!draft.measured) return "available";
    if (draft.failures > 0 || draft.warnings > 0) return "researching";
    return "researched";
  };
  const state = new Map<string, T27EvolutionState>(
    drafts.map((draft) => [draft.id, ownState(draft)]),
  );

  const unlocks = new Map<string, string[]>();
  for (const draft of drafts) {
    for (const id of draft.prerequisites) {
      unlocks.set(id, [...(unlocks.get(id) ?? []), draft.id]);
    }
  }

  const nodes: T27EvolutionNode[] = drafts.map((draft) => {
    const own = state.get(draft.id) ?? "locked";
    const maturity: T27EvolutionNode["maturity"] =
      own === "researched"
        ? "shipped"
        : own === "researching"
          ? "partial"
          : own === "available"
            ? "unknown"
            : "blocked";
    const blockedBy = draft.prerequisites.find(
      (id) => measured.get(id) !== true,
    );
    return {
      id: draft.id,
      label: draft.label,
      layer: draft.layer,
      maturity,
      state: own,
      evidence: draft.evidence,
      ...(draft.note ? { note: draft.note } : {}),
      ...(blockedBy ? { blockedBy } : {}),
      prerequisites: draft.prerequisites,
      unlocks: unlocks.get(draft.id) ?? [],
    };
  });

  const layers = ["seed", "language", "check", "backend", "adoption", "silicon"];
  const edges = drafts.flatMap((draft) =>
    draft.prerequisites.map((from) => ({ from, to: draft.id })),
  );
  const count = (value: T27EvolutionState) =>
    nodes.filter((node) => node.state === value).length;
  const researched = count("researched");

  return {
    nodes,
    edges,
    layers: layers.filter((layer) => nodes.some((node) => node.layer === layer)),
    summary: {
      total: nodes.length,
      researched,
      researching: count("researching"),
      available: count("available"),
      locked: count("locked"),
      percentage: nodes.length
        ? Math.round((researched / nodes.length) * 100)
        : 0,
    },
    source: { repo, commit, specs: specCount },
  };
}
