# SOUL.md — Agent Soul Binding

**Law**: Every container/agent MUST have `SOUL.md` at root.

---

## Agent Identity

| Field | Value |
|-------|--------|
| **Agent Type** | Custom — Queen web surface (no autonomous loop) |
| **Agent ID** | `queen-web` |
| **Bound Issue** | `#476` |

---

## Mission

```markdown
Serve the Queen dashboard as a static surface on Railway.

This container carries the React UI only. It executes nothing on the user's
behalf, holds no credentials, and makes no autonomous decisions — so the
8-step agent cycle, the MNL pattern and Akashic journaling do not apply to it.
It is bound to issue #476 because that is the issue the Queen deployment has
always been reported against.
```

---

## Allowed Commands

```markdown
npm ci          — install from the committed lockfile
npm run build   — emit dist/
npm start       — vite preview --host 0.0.0.0 --port $PORT

Nothing else. This container has no shell entrypoint and no write access to
the Trinity tree.
```

---

## Stop Conditions

```markdown
- The build emits no dist/index.html or no JS bundle → fail, do not deploy.
- The process binds anything other than 0.0.0.0:$PORT → fail; Railway routes
  to $PORT and a loopback bind is unreachable from outside the container.
```

---

## Reporting Format

Protocol v2, on issue #476.

`✅ [DONE]` may only be posted after the deployed URL has answered. The
workflow this replaced posted "✅ Queen deployed" on every run, including all
32 failures — the claim was never once verified against a live URL.

---

## Scope — what this is NOT

The Queen's Zig backend is **not** in this container and does not currently
exist as a buildable artefact:

- `build.zig` declares 67 steps; none is named `queen-backend`, which
  `deploy/Dockerfile.queen` invokes. The closest is `libqueen`, and it builds
  the `libtrinity-queen` C API library for the SwiftUI dashboard, not a server.
- `src/server_main.zig` is a 48-line stub that answers every request with the
  same JSON, is wired into no build step, and binds `127.0.0.1`.

The brain (`src/brain`) therefore has no vehicle yet either: it is Zig, and it
would ship inside that backend once the backend exists.

---

## References

- `CLAUDE.md` — Queen Trinity Orchestrator Law
- `AGENTS.md`
- `.claude/rules/no-shell-scripts.md` — why the entrypoint is not `sh -c`
