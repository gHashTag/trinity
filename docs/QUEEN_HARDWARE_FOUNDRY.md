# Queen Hardware Foundry

## Outcome

The Research City may render real FPGA structures only from a signed public
registry whose Ed25519 public key is pinned in the website source. Repository
artifacts and historical evidence never imply that hardware is currently
online.

## Observable contract

- The website polls `/queen/public-hardware` with `cache: no-store` every five
  seconds.
- The client validates the full envelope, exact canonical JSON, pinned public
  key, Ed25519 signature, summary counts, timestamps, and device allowlist
  before returning any device.
- A missing endpoint, unsupported verifier, malformed value, wrong key, stale
  envelope, invalid signature, or stale online heartbeat returns no registry
  and therefore renders zero FPGA structures.
- `online` is accepted only with a valid `observedAt` inside the signed
  `onlineWindowSeconds`. Historical `programmed` evidence remains programmed.
- Verified devices are rendered outside the canonical research rings and are
  visibly distinguished as registered, synthesised, programmed, or online.
- The DOM status panel exposes the verification state, key ID, state counts,
  and HTTPS evidence links without exposing deployment secrets or device
  identifiers not present in the public signed payload.
- Research nodes, edges, maturity, construction progress, and worker state keep
  their existing canonical sources. The foundry does not invent resources,
  progress, connectivity, or physical capability.

## Performance and accessibility

- Hardware structures share the existing demand-driven WebGL scene and its
  reduced-motion behavior.
- Static geometry is bounded by the signed registry size and does not add a
  second animation loop.
- The verification result and every evidence link remain available in the DOM.

