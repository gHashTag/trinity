# AGENTS — Trinity S³AI / t27

This file is the **repository entry point** for humans and coding agents. It summarizes **where law lives** and **how to work safely** in this tree.

---

## 1. Read first (constitutional stack)

| Order | File | Role |
|------:|------|------|
| 1 | [`SOUL.md`](SOUL.md) | **Canonical** constitution (language policy, TDD mandate, validation). |
| 2 | [`docs/nona-03-manifest/SOUL.md`](docs/nona-03-manifest/SOUL.md) | Expanded reference; if it conflicts with root `SOUL.md`, **root wins**. |
| 3 | [`docs/T27-CONSTITUTION.md`](docs/T27-CONSTITUTION.md) | **SSOT-MATH**, **LANG-EN**, **DOCS-TREE** (where `docs/` files may live). |
| 4 | [`TASK.md`](TASK.md) + [`docs/coordination/TASK_PROTOCOL.md`](docs/coordination/TASK_PROTOCOL.md) | Multi-agent coordination, locks, anchor issue. |
| 5 | [`OWNERS.md`](OWNERS.md) | Domain ownership; each major directory may have its own `OWNERS.md`. |

Supporting: [`CONTRIBUTING.md`](CONTRIBUTING.md), [`SECURITY.md`](SECURITY.md), [`architecture/ADR-004-language-policy.md`](architecture/ADR-004-language-policy.md).

---

## 2. Agent model (27-letter alphabet)

- **Documentation map:** [`docs/README.md`](docs/README.md) — where first-party docs live (`agents/`, `coordination/`, `nona-01..03/`, `clara/`).
- **Full alphabet and roles:** [`docs/agents/AGENTS_ALPHABET.md`](docs/agents/AGENTS_ALPHABET.md) — canon for T, N, P, C, B, etc.
- **Operational agent specs (e.g. watchdogs, schemas):** [`docs/agents/AGENTS.md`](docs/agents/AGENTS.md) — complements the alphabet; not a second constitution.

Use **domain directories**, not “one folder per agent.” Primary contact for a path is the **Primary** listed in the nearest `OWNERS.md`.

---

## 3. Non-negotiables for changes

1. **Specs are source of truth** — behavior belongs in `.t27` / `.tri`; generated `gen/` output is not hand-edited (except documented exceptions).
2. **TDD inside specs** — new or changed specs need `test`, `invariant`, and/or `bench` where SOUL requires it.
3. **English + ASCII** — first-party Markdown and source comments per **LANG-EN** and **ADR-004**; grandfathered paths only in [`docs/.legacy-non-english-docs`](docs/.legacy-non-english-docs).
4. **No new Python on the verification critical path** — see **SSOT-MATH** and [`docs/nona-02-organism/TZ-T27-001-NO-PYTHON-CRITICAL-PATH.md`](docs/nona-02-organism/TZ-T27-001-NO-PYTHON-CRITICAL-PATH.md).
5. **Issue gate** — PRs should link issues (`Closes #N`) where project policy requires it.
6. **Ring / gold work** — follow [`docs/nona-01-foundation/GOLDEN-RINGS-CANON.md`](docs/nona-01-foundation/GOLDEN-RINGS-CANON.md) for parser/compiler/spec changes; compiler seal path: `bootstrap/stage0/FROZEN_HASH`.

---

## 4. Layout reminders (after repo hygiene refactors)

- **Core:** `specs/`, `compiler/`, `bootstrap/`, `gen/`, `conformance/`, `tests/`.
- **Non-core services & tooling:** `contrib/backend/`, `contrib/portable-claude-setup/`.
- **Vendored / datasets / upstream:** `external/` (e.g. OpenCode submodule, `external/kaggle/`).

---

## 5. Law Reference

The seven **Invariant Laws (L1–L8)** are defined in [`docs/T27-CONSTITUTION.md`](docs/T27-CONSTITUTION.md#2--invariant-laws-never-change-without-constitutional-amendment):

| Law | Name | Legacy alias | Summary |
|-----|------|-------------|---------|
| **L1** | TRACEABILITY | ISSUE-GATE | No code merged without `Closes #N` |
| **L2** | GENERATION | NO-HAND-EDIT-GEN | Files under `gen/` are generated; edit specs instead |
| **L3** | PURITY | SOUL-ASCII | Source files must be ASCII-only with English identifiers |
| **L4** | TESTABILITY | TDD-MANDATE | Every `.t27` spec must contain `test`/`invariant`/`bench` |
| **L5** | IDENTITY | PHI-IDENTITY | φ² = φ + 1; φ² + φ⁻² = 3; IEEE f64 checks use tolerance |
| **L6** | CEILING | TRINITY-SACRED | `FORMAT-SPEC-001.json` + `gf16.t27` are numeric SSOT |
| **L7** | UNITY | NO-NEW-SHELL | No new `*.sh` on critical path; use `tri`/`t27c` |

**Law Priority:** L1 > L2 > L3 > L4 > L5 > L6 > L7 > L8 (Asimov-style hierarchy)

---

## 6. Cursor / automation

- Rule file: [`.cursor/rules/t27-ssot-math.mdc`](.cursor/rules/t27-ssot-math.mdc) — keep in sync with **SSOT-MATH** and this entry point.

---

**φ² + 1/φ² = 3 | TRINITY**

---

## 5. Law Reference

The seven **Invariant Laws (L1–L8)** are defined in [`docs/T27-CONSTITUTION.md`](docs/T27-CONSTITUTION.md#2--invariant-laws-never-change-without-constitutional-amendment):

| Law | Name | Legacy alias | Summary |
|-----|------|-------------|---------|
| **L1** | TRACEABILITY | ISSUE-GATE | No code merged without `Closes #N` |
| **L2** | GENERATION | NO-HAND-EDIT-GEN | Files under `gen/` are generated; edit specs instead |
| **L3** | PURITY | SOUL-ASCII | Source files must be ASCII-only with English identifiers |
| **L4** | TESTABILITY | TDD-MANDATE | Every `.t27` spec must contain `test`/`invariant`/`bench` |
| **L5** | IDENTITY | PHI-IDENTITY | φ² = φ + 1; φ² + φ⁻² = 3; IEEE f64 checks use tolerance |
| **L6** | CEILING | TRINITY-SACRED | `FORMAT-SPEC-001.json` + `gf16.t27` are numeric SSOT |
| **L7** | UNITY | NO-NEW-SHELL | No new `*.sh` on critical path; use `tri`/`t27c` |

**Law Priority:** L1 > L2 > L3 > L4 > L5 > L6 > L7 > L8 (Asimov-style hierarchy)


## Own language first

When this project publishes something about itself, it publishes in **this
project's own language and format** -- not translated into somebody else's.

Owner's rule, 2026-09-20: stop writing in other people's languages, we have our
own.

This bites on any file whose only reason to exist is that an outside tool
expects that shape: `llms.txt`, `agents.json`, `ai.txt`, `.well-known/*.json`,
A2A agent cards, `ai-plugin` manifests, OpenAPI stubs, JSON-LD blocks, a README
that restates a spec. The reflex is to write four of them in four foreign
formats, and the reflex is wrong: a project whose claim is "here is a language
worth writing" and which then describes itself in three of other people's
formats has published three documents that are not true of it.

**The move:** find the address the outside world already fetches, then serve our
own language at it. `/llms.txt` at t27.ai **is** a t27 module -- `llms.txt`
requires nothing but text, and every prose line of a `.t27` file is a `;`
comment, so it stays readable to anything that cannot compile it.

**Three qualifications, so the rule stays honest:**

- A format a resolver genuinely parses -- a sitemap, `package.json`, a lockfile
  -- is machinery, not a description. **Generate** it from our own source; never
  hand-write it into a second home for the truth.
- Code against someone else's API uses their types. Prose for a human who has
  never heard of the project uses that human's language.
- If a format demands a claim we cannot back, **publish nothing**. An A2A card
  with no A2A server behind it is a false claim, and a missing file is more
  honest than a lying one.

The test: *is this file the project speaking about itself?* If yes, it speaks
our language. If it is plumbing, it speaks the plumbing's.

**Worked example, compiler-checked rather than asserted:** in `gHashTag/trinity`,
`apps/website/public/t27/files/specs/catalog/onboarding.t27` generates
`/llms.txt` and `/agents.t27` byte-identically, gated in CI as
`check:onboarding`. The generator evaluates the spec's own `test` blocks --
`typecheck.ok` stays true for `assert 1 > 2`, so a compiler saying "this parses"
is not a compiler saying "this is true" -- and re-compiles the rendered document
before writing it.

**The full rule lives in exactly one place: the `own-language-first` skill**
(`~/.claude/skills/own-language-first/SKILL.md`). It carries the consent gate for
documents addressed to other people's agents, the six negative controls, and the
`;`-alone-on-a-line trap that silently discards a `module` declaration. This
section is a pointer, not a copy -- the recorded defect in this codebase family
is the hand-copied rule that only two of its three homes knew about.
