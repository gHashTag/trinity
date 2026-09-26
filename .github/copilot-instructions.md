# ⛓️ GOLDEN CHAIN - GITHUB COPILOT INSTRUCTIONS

## ⛔ FORBIDDEN TO CREATE:
- *.html (except runtime/runtime.html)
- *.css
- *.js  
- *.ts
- *.jsx
- *.tsx
- *.zig in var/trinity/output/ (GENERATED ONLY!)
- *.py (GENERATED ONLY!)

## ✅ THE ONLY WAY TO WRITE CODE:

1. Create .vibee specification in specs/tri/
2. Run: ./bin/vibee gen specs/tri/feature.vibee
3. Test: zig test var/trinity/output/feature.zig
4. Write TOXIC VERDICT (self-criticism)
5. Propose 3 options from TECH TREE

## 📝 .vibee FORMAT:

```yaml
name: module_name
version: "1.0.0"
language: zig
module: module_name

types:
  TypeName:
    fields:
      field1: String
      field2: Int

behaviors:
  - name: function_name
    given: Precondition
    when: Action
    then: Result
```

## 🔥 AFTER EVERY TASK:

### TOXIC VERDICT (mandatory!):
- What was done
- What failed  
- Metrics (before/after)
- Harsh self-criticism
- Score X/10

### TECH TREE SELECT (mandatory!):
Propose 3 options for next research:
- [A] Name, complexity ★☆☆☆☆, potential +X%
- [B] Name, complexity ★★☆☆☆, potential +X%
- [C] Name, complexity ★★★☆☆, potential +X%
- Recommendation: [A/B/C] because...

## 🚫 NEVER DO:
- Don't write .zig code directly
- Don't edit var/trinity/output/*
- Don't create legacy files
- Don't skip toxic verdict
- Don't skip tech tree select

## φ² + 1/φ² = 3

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
