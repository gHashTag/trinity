# specs/trinity -- the Trinity project manifest as `.t27` specs

> **Where this lives.** `specs/trinity/` in `gHashTag/t27` is the canonical home of the project
> manifest of `gHashTag/trinity` -- edit it here. The consumer vendors a byte-identical copy under
> `apps/website/public/t27/files/specs/trinity/` and generates its own manifest from that copy
> (S12 of gHashTag/trinity#988). Nothing in the consumer is a second authored registry.

Work package **S01** of the epic gHashTag/trinity#988 (gHashTag/t27#3563): the canonical inventory
of what `gHashTag/trinity` ships at a pinned revision, one capability per card, each with an owner,
a disposition, a canonical spec, its implementation and generated paths, its backend, its build
targets, the command that is its acceptance, the status of its evidence and the work package that
owns its contract.

## The files

| file | module | what it declares |
|---|---|---|
| `project.t27` | `trinity_project` (`KIND = "project"`) | the consumer repository and the pinned revision, the profiles, the disposition and evidence vocabularies, the dialect and build counts the inventory measured, the dependency pins and the twelve work packages |
| `capabilities/<id>.t27` | `trinity_capability_<id>` (`KIND = "capability"`) | one capability; `ID = trinity/<id>` |
| `compiler_matrix.t27` | `trinity_compiler_matrix` (`KIND = "compiler-matrix"`) | the executable t27 subset of the headless profile: compilers, backends, stages, features with fixtures, negatives (S02) |
| `build_graph.t27` | `trinity_build_graph` (`KIND = "build-graph"`) | the consumer's toolchain and CI commands, pins and their use, profiles, untracked outputs, generated tracked files with generators and inputs, the receipt policy (S03) |
| `conformance/trinity/build_graph.json` | -- | the derived graph: modules, import edges, packages, profiles, generated files hashed at the pin |
| `conformance/trinity/bootstrap_receipt.json` | -- | the bootstrap/fixture-profile receipt: compiler identity, fixtures and every generated output hashed over two runs |
| `conformance/trinity/compiler_matrix.json` | -- | what `tools/trinity_compiler_matrix.py run` measured, stage by stage and backend by backend |
| `conformance/trinity/inventory.json` | -- | the inventory of the pinned tree, written by `tools/trinity_manifest.py inventory` |
| `conformance/trinity/report.json` | -- | what `tools/trinity_manifest.py check` derived: counts, cards by disposition, profile, evidence and work package, findings |
| `../vsa/trinity_compat.t27` | `vsa_trinity_compat` (`KIND = "vsa-compat"`) | the VSA and numeric contract the consumer's facade actually runs: the owner of each of the sixteen re-exported operations, where the canonical `vsa_core.t27` agrees and differs, the selected reference as elementwise functions (S04) |
| `conformance/vsa_trinity_compat.json` | -- | the golden vectors of the reference and what `tools/trinity_vsa_compat.py run` replayed through the generated C |
| `../isa/ternary_encoding.t27` | `Tri27Encoding` (`KIND = "isa-encoding"`) | the TRI-27 instruction word of `src/tri27/emu/decoder.zig`: forty-seven opcodes, three layouts, the fifteen-bit immediate, the rules the owner never wrote down (S05) |
| `../isa/tri27_machine.t27` | `Tri27Machine` (`KIND = "isa-machine"`) | the TRI-27 machine of `executor.zig`: registers, memory, fetch, entry profiles, flags, every opcode's numeric rule, stack, budget, errors and status codes, exit codes, host boundary (S05) |
| `../isa/tri27_bytecode.t27` | `Tri27Bytecode` (`KIND = "isa-bytecode"`) | the `.tbin` container of `loader.zig`: header, sections, every rejection in order, where the code lands (S05) |
| `../vm/trinity_vm.t27` | `TrinityVsaVm` (`KIND = "vm-contract"`) | the VSA VM of `src/vm.zig`: opcode numbering, registers, step and run, condition codes, no budget, no serialized form, the sacred opcodes (S05) |
| `../api/c_abi.t27` | `TrinityCAbi` (`KIND = "host-abi"`) | the twenty-two exports of `src/c_api.zig` with prototypes, ownership and NULL rules; the source does not parse at the pin (S05) |
| `conformance/trinity/tri27_programs.json` | -- | twenty-two golden programs and eighteen loader vectors with final state, status and bounded trace; what `tools/trinity_tri27.py run` replayed through the generated C |
| `conformance/trinity/c_abi.json` | -- | what `tools/trinity_c_abi.py check` measured: header, source exports, agreement, the fixture's syntax check, `zig ast-check` |
| `conformance/trinity/abi/abi_fixture.c` | -- | the ABI fixture: ownership, NULL safety, clamping, normalization, the bind/unbind round trip; compiles against the header, not linked at the pin |
| `../tools/catalog.t27` | `ToolsCatalog` (`KIND = "tools-catalog"`) | the tools catalog at schema 2: repository-qualified IDs, legacy resolution, witnesses, vocabularies, the counts the consumer measures to (S06) |
| `../tools/trinity/tri/<command>.t27` | `tool_trinity_tri_<command>` (`KIND = "tool"`) | one card per command the Trinity tri exports in `.trinity/registry.json`, 29 at the pin (S06) |
| `../tools/mcp_protocol.t27` | `McpProtocol` (`KIND = "mcp-protocol"`) | what the Trinity MCP server does with a JSON-RPC message, method by method, at the pin (S06) |
| `conformance/trinity/tools_inventory.json` | -- | what `tools/trinity_tools_registry.py inventory` measured: registry, table, dispatch layers, the server literal, the help witness of the t27 tri |
| `conformance/trinity/mcp_fixtures.json` | -- | fourteen offline JSON-RPC fixtures and what `run` replayed through the generated C of the protocol spec |

## How the cards are held to the tree

```
python3 tools/trinity_manifest.py inventory --trinity-root <clean clone of gHashTag/trinity at PINNED_REVISION>
python3 tools/trinity_manifest.py check
python3 tools/trinity_manifest.py --self-check     # negative control: sixteen planted defects, each reported, and the comment and vendored-copy rules end to end
```

`inventory` refuses a tree with a modified tracked file. It reads `build.zig` (every
`addExecutable` / `addTest` / `addLibrary`, every `b.step`, every `installArtifact` and the `if`
that guards it), `build.zig.zon`, `.gitmodules`, the tracked tree (one entry per directory), the `.t27` / `.tri` /
`.vibee` / `.zig` counts with the website mirror (`apps/website/public/t27/files/`) and the
consumer's vendored copies of this repository's contracts (`external/t27/`) each set apart,
the reachability of every `.zig` file from the files `build.zig` names through relative
`@import`, `.trinity/registry.json` and the vendored catalog counts. `build.zig` and the `.zig`
files are read with their `//` comments blanked in place; a `//` inside a string or a multiline
string line is kept, so a step, an install or an `@import` that exists only in a comment is not
counted.

`check` fails on: a pinned revision or a count that differs from the inventory; a dirty
inventory; a target `build.zig` defines that no card owns, or two cards own, or a card owns
that the build does not define; a default-installed target on a non-headless card or a
`!ci_mode`-guarded target on a headless one; a `trinity:` path that is not tracked; a mirrored
or vendored file cited as canonical; a `DIALECT` that disagrees with the extension of `CANONICAL_SPEC`; a
backend claimed by a card that is not executable, adapter or research; two owners for one
canonical spec; two cards with one `ID`; `EVIDENCE = "measured"` without `ACCEPTANCE` and
`EVIDENCE_SOURCE`; a work package without a card or a card naming a package the project does
not list. The compiler remains the authority on the files: `t27c typecheck` and the seals under
`.trinity/seals/` cover every file here.

## Vocabulary

**DISPOSITION** -- what the capability is at the pinned revision:

| value | meaning |
|---|---|
| `executable` | built from source in the consumer; a backend is named |
| `declared` | present as a declaration, a placeholder or a corpus; nothing executable is claimed |
| `adapter` | handwritten code that wraps an external service, a GUI toolkit or a host, retained until generation is demonstrated |
| `external` | owned and implemented in another repository, consumed through a pin |
| `deprecated` | retained history or a duplicate; not a source of truth |
| `out-of-scope` | named so that it is not silently omitted; no work package owns it |
| `research` | an optional research artifact; its results are not project claims |
| `catalog-only` | a public snapshot (the Queen catalog); never implementation coverage |

**PROFILE** -- `headless` (the initial reproducible profile: what `zig build -Dci=true` installs
on `ubuntu-latest`), `web`, `native`, `fpga`, `training`, `network`, `research`. A target
installed by default is headless; a target guarded by `!ci_mode` is not.

**EVIDENCE** -- the five tags of `docs/system/project.md`: `measured` (a run whose output is
in a repository or a public CI log, command and revision recorded in `EVIDENCE_SOURCE`),
`declared`, `specified`, `external`, `not-claimed`. Catalog presence, source parsing,
`typecheck.ok`, an empty test set or a module shell never count as measured.

**TARGETS** -- `exe:<name>`, `lib:<name>`, `test:<root source path>`, `step:<name>` as
`build.zig` defines them; `fnmatch` patterns are allowed (`test:src/trinity_node/*`).

**Paths** -- `trinity:<path>` is a tracked file or directory of the pinned consumer tree; a bare
path is a file of this repository; `<repo>:<path>` names another repository and is recorded,
not checked.

## What the inventory measured at gHashTag/trinity@976df517 (2026-09-12, corrected 2026-10-01)

- 51 executables, 6 libraries, 73 tests and 66 steps in `build.zig`; 46 targets installed by
  `zig build -Dci=true`, 3 guarded by `!ci_mode` (photon-demo, photon-immersive and the node GUI).
  The steps `needle-mcp` and `trinity-mcp` and the installs of `trinity-canvas` and
  `trinity-canvas-wasm-check` exist only in commented-out lines. Until 2026-10-01 the inventory
  read comments and counted 68 steps and 5 guarded installs, and the two MCP cards owned the
  two steps (gHashTag/trinity#989).
- 31 `.t27` files outside the website mirror, 1044 inside it, none under `external/t27/` at this
  revision; 764 `.tri`; 1981 `.vibee` (1428 of them under `deploy/trinity-nexus`); 2830 `.zig`, of
  which 748 are reachable from the 173 files `build.zig` names and 2082 are not (749 and 2081
  until 2026-10-01: one file is reached only through a commented-out `@import`).
- Four pinned dependencies (`emsdk`, `raylib`, `zig_hdc`, `zig_golden_float`) and one submodule
  (`external/zig-golden-float`, a second, unpinned reference to the same repository).
- 29 commands in `.trinity/registry.json`; the vendored catalog holds 856 distinct specs from 8
  repositories -- a snapshot, never coverage.
- The measured evidence of the headless profile is one public CI run (`Build & Test`,
  ubuntu-latest, zig 0.15.2) in which `zig build -Dci=true` succeeded; the test step is piped
  through `tee` there and its exit code is not measured (gHashTag/trinity#616).
- One card is ahead of the pin. `brain.regions` (2026-10-04, gHashTag/t27#5953) owns the eleven
  brain test targets that gHashTag/trinity#1333 puts back into `build.zig`: five steps and six
  `src/brain` test roots. None of them exists at this revision, so `check` reports eleven
  `UNKNOWN_TARGET` findings, and `report.json` keeps them until S01 re-pins. Against an
  inventory of gHashTag/trinity@291ac8b24, the head of #1333, the card has no finding and none of
  the eleven is unassigned. `research.unreferenced-sources` no longer names `src/brain`.

## The compiler matrix (S02)

`compiler_matrix.t27` (module `trinity_compiler_matrix`, `KIND = "compiler-matrix"`) names the
native compiler (`t27c 0.2.0`, `NATIVE_REVISION` = the last commit that changed `bootstrap/`),
the vendored WASM of the site (an older revision, its own column, no runtime), the four
backends with the command that emits each and what proves a runtime result on each, the four
stages kept apart in the record, fourteen features with one fixture each under
`bootstrap/tests/fixtures/trinity_matrix/`, and five negatives with the latest stage at which
each must be rejected. `tools/trinity_compiler_matrix.py run` carries every fixture through
`t27c typecheck` and `parse --json` (annotation agreement, import resolution, declaration
count), `gen-c` / `gen` / `gen-rust` / `gen-verilog`, `cc -DT27_TEST_MAIN`, `zig test`,
`rustc --test`, `iverilog` and `t27c icarus-simulate`, and writes
`conformance/trinity/compiler_matrix.json`; `check` holds the committed record to the spec and
the fixture hashes; `--self-check` proves the negatives are negatives.

Measured on 2026-09-12 (compiler sources at `bff21b85`, host clang 21, rustc 1.94, Icarus 13,
zig 0.17.0-dev nightly because zig 0.15.2 cannot link on the host): 12 of 14 features reach a
runtime pass on their backend; `enums` is blocked on C (the enum declares `EVIDENCE_EMULATOR`,
the switch compares against `EMULATOR`) while it executes on Zig; `ffi_boundary` is blocked at
declaration (a bodyless signature is a parse error, gHashTag/t27#3472). The Rust backend emits
declarations only (`NOT LOWERED`) for every fixture. The Zig backend does not lower string
equality, array constants, invariant blocks or the clocked form. All five negatives are
rejected: the invalid annotation and the unresolved import by this tool at declaration (the
compiler and the vendored WASM accept both with `typecheck.ok`), the false assertion at
runtime, the bodyless function and the dropped module by the parser.

```
python3 tools/trinity_compiler_matrix.py run --zig <zig> --wasm <trinity>/apps/website/public/t27/t27_compiler.wasm
python3 tools/trinity_compiler_matrix.py check
python3 tools/trinity_compiler_matrix.py --self-check
```

## The build graph and the receipts (S03)

`build_graph.t27` (module `trinity_build_graph`, `KIND = "build-graph"`) declares what the
consumer's build is made of: the Zig the consumer requires and the one its CI measures with,
the CI build and test commands (and that the test exit code does not reach the job,
gHashTag/trinity#616), the `build.zig` options, the four `build.zig.zon` pins with how
`build.zig` actually uses each, the submodule, the seven profiles with what is measured for
each, the untracked build outputs, the fourteen tracked files a generator writes (with the
generator and the inputs it reads), the seven directories that are generator output
locations, and the receipt policy of the bootstrap/fixture profile (two independent runs,
no normalization). `tools/trinity_build_receipt.py graph --trinity-root` derives the graph
from the pinned tree into `conformance/trinity/build_graph.json` -- every named module with
its root, every import edge resolved to a module, a package module or an inline module -- and
hashes each generated file and its inputs at the pinned revision (blob hashes for files,
tree hashes for directories). `receipt` writes `conformance/trinity/bootstrap_receipt.json`:
the compiler-source revision, the `t27c` hash, the host, and the hash of what each backend
generated from each matrix fixture in two runs. `check` recomputes what can be recomputed
offline (the compiler sources, `Cargo.lock`, the fixtures and a fresh generation must match
the receipt) and, with `--trinity-root`, judges drift in the consumer: a generated file that
changed while its inputs did not is a suspected hand edit, inputs that changed while the file
did not make it stale, and JSON in a generated location that no entry registers is
unregistered. `--self-check` plants each of those.

Measured on 2026-09-12 at gHashTag/trinity@976df517: 44 named modules, 252 import edges (84 to
named modules, 152 to the package modules `zig-hdc-vsa` of zig_hdc and `golden-float` of
zig_golden_float, 16 to inline modules, 0 unresolved); `emsdk` is pinned but not referenced by
`build.zig` directly; the receipt of the bootstrap/fixture profile is deterministic: 2 runs
over 18 fixtures x 4 backends, 72 outputs, 0 differing (gHashTag/t27#3006's wobble does not
reach this profile); the consumer's 14 generated tracked files show no drift at the pin.

```
python3 tools/trinity_build_receipt.py graph --trinity-root <clean clone at PINNED_REVISION>
python3 tools/trinity_build_receipt.py receipt --runs 2
python3 tools/trinity_build_receipt.py check --trinity-root <clone>
python3 tools/trinity_build_receipt.py --self-check
```

## The VSA compatibility contract (S04)

`../vsa/trinity_compat.t27` (module `vsa_trinity_compat`, `KIND = "vsa-compat"`) is the
contract behind `trinity:src/trinity.zig`, which re-exports sixteen VSA operations from the
package the consumer pins (gHashTag/zig-golden-float `e7ce3288`, `src/vsa/core.zig`, passed
through gHashTag/zig-hdc `b73b2fa2` name by name). `specs/vsa/vsa_core.t27` describes the same
names with other semantics, so the spec records, per export, the owner function (file:line),
the canonical function (name:line), a finding and a verdict: 4 agree on every input
(`permute`, `inversePermute`, `countNonZero`, `vectorNorm`), 6 agree on equal lengths only
(`bundle2`, `bundle3`, `cosineSimilarity`, `hammingDistance`, `hammingSimilarity`,
`dotSimilarity`) and 6 differ in kind (`bind` and `unbind` -- the owner annihilates on a zero
trit, the canonical spec keeps it as an identity -- `encodeSequence`, `probeSequence`,
`randomVector`, `bundleN`). The semantics the pinned consumer executes are the reference of
the Trinity profile and are stated as elementwise functions the C backend runs, because the
compiler does not lower array parameters (S02): `trit_bind`, `trit_bundle2`, `trit_bundle3`,
`trit_differs`, `trit_nonzero`, `len_max`, `len_min`, `rotate_right`, `rotate_left`,
`packed_bytes`, `cosine_defined`, `tri27_bind`. The zero-identity bind of `vsa_core.t27` and
`ops.t27` and the additive TRI27 register bind of `src/tri27/emu/executor.zig` are classified
separately, each with its own function. The numeric representation is declared: i8 trits, five
to a byte, two capacities in one package (12000 packed, 59049 hybrid), SIMD width 32, an i32
dot accumulator in the owner, f64 similarities, no GoldenFloat format on the facade, no
allocation and no error in the sixteen operations.

`tools/trinity_vsa_compat.py vectors` writes `conformance/vsa_trinity_compat.json` from a
Python statement of the owner's semantics (149 vectors over 15 operations: equal lengths, one
SIMD chunk, a chunk plus a remainder, unequal lengths, all-zero and empty vectors, ties, the
rotation identities and the inverse law, the TRI27 fix-up; the pseudo-random trits come from the
tool's own LCG, not from the owner's PRNG). `run` generates the spec to C with `t27c gen-c`,
composes the elementwise functions into whole-vector operations in a C driver whose length
rules are the spec's own `len_max`, `len_min` and `rotate_*`, replays every vector and records
the verdict with the compiler, the C compiler and the spec hash. `check` holds the committed
record to the spec and the model; `--self-check` proves a wrong expected trit fails exactly its
vector and that a zero-identity bind planted into the spec fails only bind-shaped vectors.

Measured on 2026-09-12: `All 10 tests passed.` for the spec on C; 149 of 149 vectors pass the
replay. Not measured: the owner's Zig itself -- the package does not build with the Zig
available on this host (0.15.2 cannot link against the host SDK, the 0.17 nightly rejects the
package), so the reference is read from the owner's source and the spec says so
(`NOT_MEASURED`); a differential run against the owner remains the owner's own test suite.

```
python3 tools/trinity_vsa_compat.py vectors
python3 tools/trinity_vsa_compat.py run
python3 tools/trinity_vsa_compat.py check
python3 tools/trinity_vsa_compat.py --self-check
```

## The VM, the TRI-27 bytecode and the host ABI (S05)

The consumer has two virtual machines and one C boundary, and none of the three had an
executable contract. `../isa/ternary_encoding.t27`, `../isa/tri27_machine.t27` and
`../isa/tri27_bytecode.t27` state the TRI-27 layer as the owner's tests execute it --
`src/tri27/emu/decoder.zig`, `executor.zig` with `cpu_state.zig`, and `loader.zig` at the pin --
rule by rule, as functions the C backend runs: field extraction and encoding, opcode validity,
the numeric rule of every executed opcode, flags, bounds, stack, budget, jumps, and every
container check. `tools/trinity_tri27.py vectors` assembles twenty-two golden programs in the
decoder's layout and runs them through a Python model of the same three files, writing
`conformance/trinity/tri27_programs.json` with final registers, flags, memory changes, status and
a bounded trace, plus eighteen loader vectors (one per rejection rule and per accepted shape).
`run` generates the three specs to C, links them into a driver that owns the arrays and the loops
and calls the specs for every decision, and replays. `check` holds the record to the specs and the
model; `--self-check` plants a wrong register, a rejection declared as acceptance, a `BIND` without
its zero identity and a wrong sign bit. The status codes are the machine spec's own, because the
owner's error set has no ordinals and three of its halts are silent: `halted` is 0, everything else
is nonzero.

What the replay found, and the specs record as findings: `CALL` pushes its own address and `RET`
returns to it, so every subroutine call loops until the budget; `loader.load` writes eight-byte
words while `run` fetches four-byte units, and reads a `tri_asm.zig` container two bytes early, so
nothing it loads runs as written (the owner's tests copy the file to byte 0 and start at word 3);
`DOT`, `BIND`, `BUNDLE2` cannot carry a second register and `SACR` cannot carry its mode through
the encoding; no encodable load or store can leave memory; the `CONSTANTS` section's id byte is
read as its count; `3^27` is written where `3^9` is computed; five instruction layouts, two
assemblers and an emitted template disagree with the decoder.

`../vm/trinity_vm.t27` states the VSA VM of `src/vm.zig` (twenty-six opcodes numbered by
declaration order, four hyperdimensional registers over S04's operations, no budget, no
serialized form, forty sacred opcodes of which six are implemented) and records its CI evidence as
it is: `zig test src/vm.zig` fails to compile on every push to main. `../api/c_abi.t27` states the
twenty-two C exports with prototypes, ownership and NULL rules; `tools/trinity_c_abi.py check
--trinity-root` holds the table to the header and to the source (all twenty-two agree), compiles
`conformance/trinity/abi/abi_fixture.c` against the header, and records that `zig ast-check`
rejects `src/c_api.zig` at the pin (a duplicated `if` in `trinity_vsa_set_trit`), so the library
and its tests do not build and the fixture is not linked.

Measured on 2026-09-12: `All N tests passed.` on C for the five specs (11, 10, 6, 5, 4); 40 of 40
vectors pass the replay; 22 of 22 ABI functions agree across spec, header and source; the fixture
compiles. Not measured: anything on the owner's Zig (no build target, binaries that do not compile,
no Zig on this host that builds the tree); the string and file opcodes; `SACR` modes 2..4; the VSA
VM's programs; the ABI across a linked boundary. No hardware is involved.

```
python3 tools/trinity_tri27.py vectors
python3 tools/trinity_tri27.py run
python3 tools/trinity_tri27.py check
python3 tools/trinity_tri27.py --self-check
python3 tools/trinity_c_abi.py check --trinity-root <clone at PINNED_REVISION> [--zig <zig>]
python3 tools/trinity_c_abi.py --self-check
```

## The CLI and MCP commands from one registry (S06)

`../tools/catalog.t27` names the one artifact the consumer's own binary exports and its CI holds
to the binary -- `.trinity/registry.json`, 29 commands, the `mcp_enabled` subset of a 187-entry
table -- as the registry the Trinity cards derive from, and states the catalog at schema 2: every
card under `specs/tools/` carries `REPO`, `QUALIFIED_ID` (`<owner>/<repo>:<family>/<name>`) and
`SCHEMA = 2`; the 62 legacy cards keep their short `ID` and gain the qualified one; a Trinity card
(`../tools/trinity/tri/<command>.t27`) has only the qualified ID, so a same-named command of the
two binaries (`fpga`, `test`) is never selected by the wrong repository, and a legacy ID resolves
through a 62-pair table and nothing else. Each Trinity card carries the registry's fields, the
dispatcher's routing (six of the 29 reach no dispatcher at the pin), the exit-code and result
rules as they are, and the witness `registry-export`. `../tools/mcp_protocol.t27` states what
`tools/mcp/trinity_mcp/server.zig` does with a JSON-RPC message: stdio only, substring method
matching, no negotiation, silence for notifications and unknown methods, a 210-tool literal of
which 32 objects are malformed JSON, exact-prefix-generic call routing with no refusal, failures as
`isError` results, no cancellation, no timeout, no permission gate at the server.

`tools/trinity_tools_registry.py inventory --trinity-root <clone> --tri target/release/tri`
measures the clone and the built t27 `tri` (the `help-output` witness of the 52 t27 cards: 52 of
52 agree) into `conformance/trinity/tools_inventory.json`; `check` holds the 29 cards to the
registry field by field (an unexplained addition or removal fails), every card to schema 2, and the
two contracts' counts to the measurement; `fixtures` and `run` write and replay fourteen offline
JSON-RPC fixtures through the generated C of the protocol spec (14 of 14); `--self-check` plants
the defects each must catch.

Not measured: any Trinity command or MCP tool running -- no host here builds the binary, and no
workflow runs one without `|| true` or a server at all. The site generator in gHashTag/trinity
reads only `tri/` and `mcp/` and refuses unknown constants; schema 2 needs its companion change
before the vendored copy is refreshed.

```
python3 tools/trinity_tools_registry.py inventory --trinity-root <clone at PINNED_REVISION> --tri target/release/tri
python3 tools/trinity_tools_registry.py check
python3 tools/trinity_tools_registry.py fixtures
python3 tools/trinity_tools_registry.py run
python3 tools/trinity_tools_registry.py --self-check [--trinity-root <clone>]
```

## The agent loop, its permission boundary and its context budget (S07)

Three specs under `specs/api/` state `src/tri-api` of gHashTag/trinity at `afc9d384` (the tree is
byte-identical to the issue's baseline `03ae2f93` and to the S01 pin `976df517`): `tri_api_loop.t27`
(`TriApiLoop`, `KIND = "agent-loop"`), `tri_api_permissions.t27` (`TriApiPermissions`,
`"agent-permissions"`) and `tri_api_context.t27` (`TriApiContext`, `"agent-context"`). Card:
`trinity/agent.tri-api`. They cover what
[gHashTag/t27#3569](https://github.com/gHashTag/t27/issues/3569) asks for: the provider
configuration, what the reply scanner sees, how a turn ends, the twenty-request budget, the context
threshold and what compaction loses, the deny-over-allow table and its limits, the path and bash
predicates, the checkpoint that runs before a write, MCP routing, and the provider features the loop
does not use. Twenty-nine findings are recorded, each tagged with the evidence that measured it.

Three kinds of evidence, kept apart in `tools/trinity_tri_api.py`:

- **model**: a Python reading of the source, 149 vectors (148 that return, one that never does);
- **zig**: the pinned files compiled with Zig 0.15.2 and run -- their own 32 unit tests plus a
  generated test block appended to a copy of each file, in Debug, ReleaseSafe, ReleaseFast and
  ReleaseSmall; the model agrees with the compiled Zig on 148 of 148 vectors in every mode;
- **binary**: the real `tri-api` built from `main.zig` and driven through 24 scenarios against a
  scripted Messages server and a scripted MCP server (`conformance/trinity/tri_api_e2e.json`).

The one the owner should read first: the permission rules parsed from `settings.json` are slices into a
buffer the loader frees. In Debug and ReleaseSafe the freed bytes read `0xAA`, an allow rule never
allows and `deny read_file(.env)` still reads `.env`; in ReleaseFast and ReleaseSmall the bytes survive by
accident and the table works. Next to it: a pretty-printed settings file loads no rules and a mixed one
drops its deny rules; the bash allowlist lets `&`, `>`, `env <cmd>`, `find -delete` and `sed -i` through; the
git checkpoint runs before the path predicate, so a refused write still stashed the file's local edits; a
provider error, a garbage reply and the turn limit all exit 0 with nothing on stdout; usage tokens are always
0; a tool-use block with a second `type` key never returns; an MCP server that follows the protocol yields no
tools and one that does not kills the process.

Not measured: a real provider, a real model, streaming, a real MCP server, a model deciding to attack, a
Linux host (the harness ran on macOS arm64; `grep` needs a `timeout` binary that host lacks). No credential
enters anything: the binary gets a fake key and a local address.

```
python3 tools/trinity_tri_api.py inventory --trinity-root <clone at afc9d384>
python3 tools/trinity_tri_api.py vectors
python3 tools/trinity_tri_api.py zig --trinity-root <clone> --zig <zig 0.15.2> [--sysroot <dir>]
python3 tools/trinity_tri_api.py e2e  --trinity-root <clone> --zig <zig 0.15.2> [--sysroot <dir>]
python3 tools/trinity_tri_api.py run
python3 tools/trinity_tri_api.py check
python3 tools/trinity_tri_api.py --self-check [--trinity-root <clone> --zig <zig>]
```

## What tri-api keeps between runs, and the designs that described it (S08)

`specs/api/tri_api_session.t27` (`TriApiSession`, `KIND = "agent-session"`) states what `src/tri-api`
of gHashTag/trinity at `afc9d384` keeps on disk -- a record per run under `$HOME/.trinity/api/sessions`
with an `index.json`, the memory file `$HOME/.tri-api/MEMORY.md`, git-stash checkpoints, the audit log --
and what it does with them: format, write discipline, `--continue` and `--resume`, recovery from damaged
records, retention, provenance, compaction as saved, privacy. Card: `trinity/state.trinity-dir`. Issue:
[gHashTag/t27#4827](https://github.com/gHashTag/t27/issues/4827), re-filed from #3570. Twenty findings,
f30 to f49, each tagged with its evidence.

It reuses the existing designs rather than copying them, and says what each is worth. `organism/dna.tri`
and `organism/mozg.tri` do not parse under t27c and have bodies and helpers nowhere; they now carry that
status, and the spec's `MAPPING` shows which of their fields tri-api has (almost none). `brain/unified_state.t27`
describes a state nothing persists and does not compile in C at master (an enum-literal lowering). And
`memory/tmem/session.t27`, the TMSS record of the optional tmem adapter, compiled in neither backend -- not at
master and not at its own merge commit `8bde3bb7a` with the command its docs/now entry records as passing.
It is fixed in place here (assert instead of an undeclared `eq`, if-chains instead of two switches that
returned nothing in C, a declared helper, a test that no longer repeats its neighbour): 24 of 24 in C and in
Zig. `conformance/tmem_session.json` carried a magic of `0x534C83C4` for the spec's `0x53534D54`; corrected.
The adapter is decided as optional and not enabled: nothing reads or writes a TMSS record, and a tri-api record
fails its header rule (replayed through the generated C of both specs).

Evidence, kept apart in `tools/trinity_tri_api_session.py` (which reuses S07's harness):

- **model**: a Python reading of `save`, `load`, `loadLatest` and `Memory.load`;
- **zig**: `session_store.zig` and `memory.zig` compiled with Zig 0.15.2 and generated fixtures in four modes --
  eight save/load round trips, every one of the 343 prefixes of a saved record loaded back, the index preview,
  five memory files; the model and the Zig agree on every answer in every mode;
- **binary**: the real `tri-api`, twelve scenarios in a private HOME against the scripted provider.

The two the owner should read first. Two saves in one second share an id: eight runs started together left one
record in each of ten trials, and the index, rewritten without a lock, lost entries in some of them. And a tool
output over 200 bytes that ends in a backslash makes context truncation cut across messages: the request, the
saved record and every later `--continue` are invalid JSON. Next to them: the write is not atomic and a failed
write is silent; a damaged record is announced as resumed while its history is dropped; there is no fallback and
no version; `MEMORY.md` is never written and is dropped entirely past 256 KiB; transcripts with the contents of
files a tool read are stored 0644; a compaction summary claiming a denied write completed is sent and saved in
place of the denial; no checkpoint can be restored.

Not measured: a real provider or model, a host other than macOS arm64 (modes measured under umask 022), power
loss. Not decided here: owners for `specs/memory/` and `specs/organism/` (`memory/tmem/OWNERS.md` points to a
`specs/memory/OWNERS.md` that does not exist).

```
python3 tools/trinity_tri_api_session.py zig --trinity-root <clone at afc9d384> --zig <zig 0.15.2> [--sysroot <dir>]
python3 tools/trinity_tri_api_session.py e2e --trinity-root <clone> --zig <zig 0.15.2> [--sysroot <dir>]
python3 tools/trinity_tri_api_session.py run
python3 tools/trinity_tri_api_session.py check
python3 tools/trinity_tri_api_session.py --self-check [--trinity-root <clone> --zig <zig>]
```

## The Queen's task lifecycle, and the cycles that only describe one (S09)

`specs/queen/dispatch.t27` (`QueenDispatch`, `KIND = "queen-dispatch"`) is the canonical state machine of a
Queen task: choose, start, end, review, retry, release. It is taken from the one cycle in this family that
moves work, the round of the trios supervisor (gHashTag/BrowserOS `trios/agent-server`, branch
`feat/queen-supervisor` at `c25e1b02`), and it names the others as adapters with their gaps:
`lotus-policy` (gHashTag/trinity `src/tri/queen/lotus_cycle.zig`, a loop that tunes a resource policy and
holds no task; `specs/queen/lotus.t27` is its design), the six AGENTS.md phases (documented as
`tri queen lotus --phase`, implemented nowhere), the AEL v2.0 loop of an agent session and the PHI LOOP of a
change. Cards: `trinity/queen.lib`, `trinity/agent.phi-loop`. Issue:
[gHashTag/t27#4828](https://github.com/gHashTag/t27/issues/4828), re-filed from #3571. Fifteen findings,
f50 to f64.

The evidence runs the supervisor's own code, five kinds kept apart in `tools/trinity_queen_dispatch.py`:

- **ts**: its TypeScript under bun -- the claim a row exerts over 2112 inputs, the public board's column,
  the single-flight round gate;
- **queend**: its Swift policy binary built at the pin -- choose over all 120 orders of five candidates,
  capacity, review over a grid, retry over every sequence of failure kinds;
- **pg**: PostgreSQL 16 with its own migrations -- the singleton lease under 32 contenders for 20 rounds,
  expiry and fencing, the dispatch writers on real rows, the criteria release, the CI take-back, and the
  round's own SELECT read out of the pinned source;
- **lotus**: the Zig cycle compiled with Zig 0.15.2, 29 of 29 tests in Debug and ReleaseFast;
- **live**: one snapshot of the deployed supervisor's public endpoints.

`run` replays the spec through the generated C on 2488 cases drawn from these records; `--self-check`
plants sixteen faults and shows each caught.

What the owner should read first. There is no priority and no dependency resolution: the first eligible
issue in GitHub's listing order is taken. The one-release bound of a spent retry ceiling never applies,
because neither the round nor the board selects `ceiling_releases`: a stored 1 reads as 0 and the issue is
handed back every hour. The public board draws a closed issue as done whatever its verdict. Accept needs
criteria, a commit and a reviewer, but no pull request, CI or merge. One Queen at a time holds under
contention, but the dispatch writer itself enforces nothing, a bee has no heartbeat (reaped by age at 120
minutes), and nothing cancels one. The 27 named agents are documentation, not workers.

`specs/queen/task_analysis.t27` is fixed in place: it sorted by returning its input and did not compile;
it now orders by its score with tests on unsorted input (7 of 7 in C and Zig) and says no runtime applies
it. `specs/queen/lotus.t27` carries its status. The S07 and S08 card seals, left stale by those PRs, are
refreshed here.

Not measured: GitHub, a real provider or bee, the Mac app's own loop, the revision Railway actually runs.

```
python3 tools/trinity_queen_dispatch.py ts    --browseros-root <checkout at c25e1b02> --bun <bun 1.3.6> --queend <queend>
python3 tools/trinity_queen_dispatch.py pg    --browseros-root <checkout> --bun <bun> --database-url <throwaway postgres>
python3 tools/trinity_queen_dispatch.py lotus --trinity-root <clone at afc9d384> --zig <zig 0.15.2> [--sysroot <dir>]
python3 tools/trinity_queen_dispatch.py live
python3 tools/trinity_queen_dispatch.py run
python3 tools/trinity_queen_dispatch.py check
python3 tools/trinity_queen_dispatch.py --self-check
```

## The Queen's project views: identity, evidence, snapshot and live (S10)

`specs/queen/views.t27` (`QueenViews`, `KIND = "queen-views"`) is the contract between the sources of t27.ai's
views and the views themselves. Every number there comes from a dated file the build ships (the spec
manifest, the shared core, the universe atlas, the Queen's foundation) or from a public endpoint of the trios
supervisor; the spec states what identifies a repository, a source, a spec, a revision and an issue (only an
exact path or a hash is identity; a basename, a suffix, a case variant, a word match or a bare number may only
suggest an unverified candidate), the five kinds of evidence a view keeps apart (availability, generation,
coverage, runtime, lifecycle), how an address resolves and that an unresolved one is shown as unavailable and
never as another spec, how live, stale, offline, loading, unavailable and snapshot data are presented, that a
spec counts once however many places hold it, and that only an issue closed as completed with verified
acceptance may be called done. Cards: `trinity/web.site`, `trinity/catalog.spec-mirror`,
`trinity/native.queen-app` and the five others of the package. Issue:
[gHashTag/t27#4829](https://github.com/gHashTag/t27/issues/4829), re-filed from #3572. Twenty-two findings,
f65 to f86.

The evidence runs the site's own code at gHashTag/trinity `afc9d384`, six kinds kept apart in
`tools/trinity_queen_views.py`:

- **ts**: its pure TypeScript under bun -- address resolution, byte verification, the shared core's
  identity and issue matching, the atlas, the HUD, the live-cell and the paint helpers on fixtures;
- **data**: the public files of the pinned tree read whole, the mirror against gHashTag/t27 at the
  revision the manifest names, and the source lines the findings rest on;
- **live**: GitHub on the day (the states of the 1238 issues the atlas froze, the epic's sub-issues, the
  re-filed packages) and one answer of each public supervisor endpoint;
- **gates**: every check, audit and test script of the site, run here, with the workflows that run it;
- **browser**: the built site in headless Chrome over CDP at desktop and phone sizes and with reduced
  motion, every live endpoint answered from the live answers and every other host refused;
- **native**: the Swift package `apps/queen` built and tested.

`run` replays the spec through the generated C and Zig on 63 cases drawn from these records (Zig needs
`str` aliased: the backend declares none); a case where the site parts from the contract must name its
finding. `--self-check` plants faults in the records, the findings and the spec and shows each caught.

What the owner should read first. The close-up of a catalog cell joins the live board to it by issue number
alone: the board answers for gHashTag/t27, and 15 cells of other repositories show the column of the t27
issue with their number. The published atlas is the snapshot of 2026-09-24 and 132 of its 1238 "open"
issues are closed; the map says "Public snapshot, not live" and shows its date only on a selected cell. An
epic's progress counts not-planned children as closed. A capacity nobody read is printed as 0, the factory
calls static data "the live Queen ledger", and an older status answer can replace a newer one. In a frame,
the spec explorer keeps the open spec under an address that names an unknown one, and opens a spec
unverified under a wrong hash. The epic gHashTag/trinity#988 still lists S08-S11 by issues closed not
planned; `project.t27` now carries `WORK_PACKAGE_CURRENT_ISSUES` with the re-filed ones. What conforms:
the explorer's own address resolution, counting once, no issue ever painted honey, navigation by key and
touch, and the native app builds and passes its tests -- it has no project view at all.

Also here: `specs/ui/queen_evidence.t27`, which the site generated its evidence panel from while it lived
only in the site's mirror, now has its canonical copy (byte-identical); `fpga.adapter.t27` (S11) gains the
NOTE, ENABLED and test block whose absence kept `tools/trinity_manifest.py check` red on master.
`specs/docs/system.t27` is not extended: the site's docs generator refuses an unknown constant, so a new
field there lands with its consumer (S12).

Not measured: the deployed build (the pin is built here), a signed-in player, the GPU path of the hive.

```
python3 tools/trinity_queen_views.py ts      --trinity-root <checkout at afc9d384> --bun <bun 1.3.6>
python3 tools/trinity_queen_views.py data    --trinity-root <checkout>
python3 tools/trinity_queen_views.py live    --trinity-root <checkout>
python3 tools/trinity_queen_views.py gates   --trinity-root <checkout> [--chrome <path>]
python3 tools/trinity_queen_views.py browser --trinity-root <checkout> [--chrome <path>]
python3 tools/trinity_queen_views.py native  --trinity-root <checkout>
python3 tools/trinity_queen_views.py run     --zig <zig 0.15.2> [--sysroot <dir>]
python3 tools/trinity_queen_views.py check
python3 tools/trinity_queen_views.py --self-check --zig <zig 0.15.2> [--sysroot <dir>]
```

## Boundaries

- No card claims that a test passes, that a benchmark number holds or that a model answers
  well; `measured` on an executable means the artifact built in CI.
- The `.tri` and `.vibee` corpora and the ten `.t27` programs under `src/tri27` are `declared`
  until S02 states which compiler proves what for each dialect.
- `trinity:t27/` is a stale second copy of this repository's compiler and numeric specs; the
  card `specs.t27-vendored-compiler` records it as `deprecated` with `gHashTag/t27` as owner.
- A local build on macOS was attempted and is not recorded: the local zig 0.15.2 could not link
  a hello-world against the Xcode 26 SDK, which is a host defect, not a finding about the tree.

## The FPGA adapter contract (S11)

`specs/fpga/adapter.t27` (card: `trinity/fpga.adapter`) is the FPGA adapter
contract of [gHashTag/t27#3573](https://github.com/gHashTag/t27/issues/3573):
the versioned inputs a caller brings (bitstream path, sha256 tied to its
provenance, board identity under the full-IDCODE rule -- the full 32-bit value
recorded beside the printed nibble-dropped form, so a masked match can never
pass), the configuration (flasher, cable, sram/flash target), the eight
distinct error statuses, and the receipt schema `trinity.fpga-receipt.v1`
with the dry-run/device boundary: a build-only record is `hardware: false`
and must never carry a result line; a device receipt carries the bitstream
sha256, the full IDCODE, the transcript hash and an `HW RESULT: N/M
bit-exact` line. No hardware run may be inferred from synthesis (#3573's
law). `tools/trinity_fpga_adapter.py check` holds the receipts of
`conformance/trinity/fpga_adapter.json` to the contract and `self-check`
plants every defect; the device receipts are the stage-2 runs of
dmitrii-f-t27/trinity-memory on the AX7203 -- the golden chunk (dense5 and
baseline2, 320/320 Y lines bit-exact) and the #65 measurements.
